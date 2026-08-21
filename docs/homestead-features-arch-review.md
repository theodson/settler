# Homestead feature scripts — ARM / Intel review

**Subject:** `../homestead/scripts/features/` (51 scripts + `dockstead/`) on branch `support/17` @ `b18bbab`
**Reviewed:** 2026-08-20 · **Method:** static review only — no scripts executed, no VM built
**Pipeline:** `settler` (this repo, `ubuntu-vmware-16` @ `783deac`) → `homestead` → `bento`, driven by
`SETTLER_VERSION=16.0.0 HOMESTEAD_VERSION=17.0.4 bash bin/build`
**Target OS:** Ubuntu 24.04 (noble), built for both Apple Silicon (arm64) and Intel (amd64)

---

## 0. Status — four fixes applied 2026-08-21

The confirmed one-liners from §11.3 have been fixed in `homestead` (branch `support/17`, uncommitted):

| Script | Change |
|---|---|
| `openresty.sh` | arm64 now uses the `package/arm64/ubuntu` path prefix, selected via `dpkg --print-architecture` |
| `chronograf.sh` | `.deb` filename now interpolates `$(dpkg --print-architecture)` instead of hardcoding `amd64` |
| `webdriver.sh` | `[[ ]]` → POSIX `[ ]`, plus an `else` branch that logs the ARM Chrome skip |
| `r-base.sh` | `jammy-cran40` → `$(lsb_release -cs)-cran40` |

All four pass `bash -n` **and** `dash -n`.

### The §11.4 dash batch — also applied 2026-08-21

| Script | Change |
|---|---|
| `php5.6`→`php8.5` (12 files), line 15 | `[ "$X" == "disabled" ]` → `=` (dash: `[: unexpected operator`) |
| `rvm.sh:27` | bash `source` → POSIX `.`, wrapped in an `[ -s … ]` guard so it cannot become the provisioner's exit status |
| `mariadb.sh:48-50` | `<<<` herestrings → `echo … \| debconf-set-selections` (the herestring was a dash **parse** error) |
| `neo4j.sh:41,44` | bash `$SECONDS` + `[[ ]]` → `date +%s` deadline + POSIX `[ ]`, so the 60s timeout actually fires |
| `postgres-9.5.sh:46` | `echo -e` → `printf` (dash's echo has no `-e`; it printed a literal `-e `) |

`postgres-9.5.sh` was a small extension beyond the four named items — it was the last bashism in the tree and
leaving it would have meant the sweep below still had an exception.

**Result: all 51 scripts now pass `dash -n` and `bash -n`, and a tree-wide sweep for `[[ ]]`, `==` inside
`[ ]`, `<<<`, `source`, `echo -e` and `$SECONDS` returns nothing in code.** Verified 2026-08-21.

> **Correction to this document.** §5-C5 originally claimed CRAN's Ubuntu repo is amd64-only. **That was
> wrong.** Probed 2026-08-21: `noble-cran40` publishes 74 arm64 packages and `jammy-cran40` publishes 71.
> `r-base.sh` therefore moves from bucket **C** to bucket **B** — its only defect was the stale suite name,
> which is now fixed. Bucket counts below have been amended accordingly.

---

## 1. How to read this document

A feature script reaches the VM by **one of two paths**, and they run under **different shells**. Which path a
script takes decides whether a given defect actually bites.

| Path | Which scripts | Shell | What that means |
|---|---|---|---|
| **Inlined** into the packer build | **10 of 51** | **dash** — `sh -eux` | Shebang ignored. Bashisms silently misfire; `set -e` aborts the build; `set -u` trips on unset vars |
| **Shipped** to `/home/vagrant/.homestead-scripts`, run at `vagrant up` | **all 51** | **bash** — Vagrant honours the shebang | Bashisms are harmless here |

Consequently:

> A bug in a **non-inlined** script does not break the image build. It breaks the developer's box on first
> `vagrant provision`. Both matter — they just surface in different places, to different people.

The inlined set is hardcoded in `bin/use-homestead-features.sh:52,57,59` (amd64) and `:84,89,91` (arm):

```
golang  rustc  rabbitmq  minio  python  pm2  meilisearch
build-customizations.sh          # settler-local, no homestead counterpart
openjdk-17  openjdk-8  postgres-pghashlib
```

**The two lists are byte-identical.** ARM and Intel builds select exactly the same features — there is no
arch-conditional selection anywhere. All architecture divergence is handled *at runtime, inside each script*.

---

## 2. The pipeline, in brief

| Step | File:line | What happens |
|---|---|---|
| 1 | `bin/build:91-100` | Setup chain: `macos-sed-fix` → `link-to-bento.sh` → `use-homestead-features.sh` |
| 2 | `bin/link-to-bento.sh:8-12` | **Arch selector.** `[ "$(uname -p)" = "arm" ]` rewrites `pkr-builder.pkr.hcl:54` to point at `homestead_arm.sh` or `homestead_amd64.sh` |
| 3 | `bin/use-homestead-features.sh:52-66,84-98` | **Inliner.** Concatenates the 10 features into `scripts/{arm,amd64}.features` |
| 4 | `bin/use-homestead-features.sh:68,100` | Splices them into `scripts/{arm,amd64}.sh` via `sed "${insertline}r"`, anchored on `# One last upgrade check` |
| 5 | `bento/packer_templates/pkr-builder.pkr.hcl:87` | `nix_execute_command = "echo 'vagrant' \| sudo -S {{ .Vars }} sh -eux '{{ .Path }}'"` ← **the dash source** |
| 6 | `homestead/scripts/homestead.rb:269-317` | Separate Vagrant path — runs features under bash from `Homestead.yaml`'s `features:` key |

Three post-processing `sed`s are applied to the inlined text (`use-homestead-features.sh:64-67` / `:96-99`):

| sed | Effect |
|---|---|
| `/usr\/bin\/env bash/d` | Strips every inlined shebang |
| `s/exit 0/echo 'skipping exit 0'/g` | Neuters every "already installed" guard — **unanchored**, so it also hits `exit 0` inside comments |
| `s/^exit 1/echo 'skipping exit 1'/g` | **Anchored to column 0** — indented `exit 1` survives (see §9) |
| `s/\[\[ "\$ARCH" == "aarch64" \]\]/arch\|grep 'aarch64'/g` | **Now a dead no-op** — see §6 |

---

## 3. Headline findings

| # | Severity | Finding | Where |
|---|---|---|---|
| 1 | **High** · ✅ FIXED | `openresty` repo line is amd64-only; arm64 is served from a **different path prefix**. Confirmed by HTTP probe. | `openresty.sh:24` |
| 2 | **High** | `cassandra` hardcodes **10** `_amd64.deb` URLs plus an `java-8-openjdk-amd64` path | `cassandra.sh:34-42,95` |
| 3 | **High** | `mariadb` **fails to parse under dash** — a herestring. Zero lines would execute if it were ever inlined. | `mariadb.sh:48-50` |
| 4 | **Medium** · ✅ FIXED | `webdriver`'s ARM carve-out uses `[[ ]]` → under dash the test is always false → wrong branch. The tree's last broken arch test. | `webdriver.sh:25` |
| 5 | **Medium** · ✅ FIXED | `chronograf` hardcodes an amd64 `.deb`. An arm64 build **does exist** at the same version — one-line fix. | `chronograf.sh:22` |
| 6 | **Medium** | `flyway` pulls a `linux-x64` tarball bundling an **x86_64 JRE** → `Exec format error` on Apple Silicon | `flyway.sh:23-27` |
| 7 | **Medium** | `neo4j` timeout uses bash-only `SECONDS` + `[[ ]]` → dead timeout → possible infinite loop | `neo4j.sh:41,44` |
| 8 | **Low** · ✅ FIXED | `r-base` hardcodes `jammy-cran40` on a noble box. (CRAN is *not* amd64-only — see §0.) | `r-base.sh:23` |
| 9 | **Low** | 12 × `php*.sh` use `==` inside `[ ]` → dash "unexpected operator" → wrong branch | `php*.sh:15` |
| 10 | **Low** | `rvm` ends with `source` → 127 under dash → would fail the provisioner as its last command | `rvm.sh:27` |

**None of items 1-10 is in the inlined set**, so none is breaking the build running today. Items 1, 2, 5, 6, 8
break the box at `vagrant provision` time on Apple Silicon.

---

## 4. Per-script inventory

`Inln` = inlined into the packer build (runs under dash). Blank = shipped only, runs under bash at `vagrant up`.

| Script | Inln | Arch idiom | arm64 | amd64 | Verdict |
|---|---|---|---|---|---|
| `blackfire.sh` | | none | repo serves both | same | **B** |
| `cassandra.sh` | | none | **404s / wrong arch** | works | **C** |
| `chronograf.sh` | | `$(dpkg --print-architecture)` in URL | arm64 `.deb` | amd64 `.deb` | **A** ✅ fixed |
| `couchdb.sh` | | none | repo serves both | same | **B** |
| `crystal.sh` | | none | **repo has no arm64 index** | works | **C** |
| `dockstead.sh` + `dockstead/` | | none | docker multi-arch | same | **B** |
| `dragonflydb.sh` | | `$ARCH` in URL `:18-19` | `dragonfly-aarch64` | `dragonfly-x86_64` | **A** ★ |
| `elasticsearch.sh` | | none | repo serves both | same | **B** |
| `eventstore.sh` | | vendor script `:33` | *unverified* | works | **E** |
| `flyway.sh` | | none | **x86 JRE, exec fmt error** | works | **C** |
| `gearman.sh` | | none | ubuntu archive | same | **B** |
| `golang.sh` | **YES** | `[ "$ARCH" = "aarch64" ]` `:25` | `linux-arm64.tar.gz` | `linux-amd64.tar.gz` | **A** |
| `grafana.sh` | | none | repo serves both | same | **B** |
| `heroku.sh` | | vendor script `:23` | *unverified* | works | **E** |
| `influxdb.sh` | | none | repo serves both | same | **B** |
| `logstash.sh` | | none | repo serves both | same | **B** |
| `mailpit.sh` | | none | installer self-detects | same | **B** |
| `mariadb.sh` | | none | repo setup script | same | **B** (but **dash parse fail**) |
| `meilisearch.sh` | **YES** | none | installer self-detects | same | **B** |
| `minio.sh` | **YES** | `arch\|grep` `:22`, `[ "$ARCH" = ]` `:68` | `linux-arm64/{minio,mc}` | `linux-amd64/…` | **A** (two idioms) |
| `mongodb.sh` | | `[ "$ARCH" = "aarch64" ]` `:25` | `arch=arm64` | `arch=amd64` | **A** (see §8.5) |
| `neo4j.sh` | | none | repo is arch-neutral | same | **B** (but dash bugs) |
| `ohmyzsh.sh` | | none | git clone | same | **B** |
| `openjdk-17.sh` | **YES** | none | ubuntu archive | same | **B** |
| `openjdk-8.sh` | **YES** | none | ubuntu archive | same | **B** |
| `openresty.sh` | | `$(dpkg --print-architecture)` `:24` | `package/arm64/ubuntu` | `package/ubuntu` | **A** ✅ fixed |
| `php5.6`→`php8.5` (12 files) | | none | ondrej PPA builds arm64 | same | **B** (but `==` in `[ ]`) |
| `pm2.sh` | **YES** | none | npm | same | **B** |
| `postgres-9.5.sh` | | none | source build | same | **B** (dead on noble anyway) |
| `postgres-pghashlib.sh` | **YES** | none | source build | same | **B** |
| `postgresql.sh` | | none | PGDG builds arm64 | same | **B** |
| `python.sh` | **YES** | none | ubuntu archive | same | **B** |
| `r-base.sh` | | none | CRAN ships arm64 | same | **B** ✅ suite fixed |
| `rabbitmq.sh` | **YES** | `arch\|grep` → `DEB_ARCH` `:31-34` | `arch=arm64` | `arch=amd64` | **A** |
| `rustc.sh` | **YES** | none | rustup self-detects | same | **B** |
| `rvm.sh` | | none | source build | same | **B** (but `source`) |
| `solr.sh` | | none | pure-Java tarball | same | **B** |
| `timescaledb.sh` | | none | repo serves both | same | **B** (PGVER mismatch) |
| `trader.sh` | | none | `pecl` compiles locally | same | **B** |
| `webdriver.sh` | | `[ "$ARCH" != … ]` `:25` | skips Chrome, logs why | installs Chrome | **D** ✅ fixed |

★ `dragonflydb.sh` is the cleanest pattern in the tree — upstream asset names match `arch` output exactly, so it
needs no branch at all.

**Counts (after the §0 fixes):** A = 7 · B = 38 · C = 3 · D = 1 · E = 2 · **total 51**.
*Before the fixes: A = 5 · B = 37 · C = 6 · D = 1 · E = 2. Remaining bucket C: `cassandra.sh`, `flyway.sh`, `crystal.sh`.*

Only **7 lines in the entire tree** perform architecture detection, across 6 files:
`dragonflydb.sh:18`, `golang.sh:22,25`, `mongodb.sh:19,25`, `minio.sh:19,22,68`, `rabbitmq.sh:31`,
`webdriver.sh:22,25`.

---

## 5. Bucket C — latent ARM bugs, with fixes

### C1. `openresty.sh:24` — wrong repo path for arm64 · **CONFIRMED by probe** · ✅ FIXED

```sh
echo "deb [signed-by=…/openresty.gpg] http://openresty.org/package/ubuntu noble main" | sudo tee …
```

OpenResty does not use an `arch=` qualifier — it serves arm64 from a **different path segment**. Probed
2026-08-20:

| URL | Result |
|---|---|
| `…/package/ubuntu/dists/noble/main/binary-arm64/Packages` | **404** |
| `…/package/ubuntu/dists/noble/main/binary-amd64/Packages` | 200 |
| `…/package/arm64/ubuntu/dists/noble/main/binary-arm64/Packages` | **200** |

So on Apple Silicon `apt-get update` cannot index this source and `openresty.sh:28 apt-get install -y openresty`
fails. Fix:

```sh
if [ "$(dpkg --print-architecture)" = "arm64" ]; then
    OR_PATH="arm64/ubuntu"
else
    OR_PATH="ubuntu"
fi
echo "deb [signed-by=…/openresty.gpg] http://openresty.org/package/${OR_PATH} noble main" | sudo tee …
```

### C2. `cassandra.sh:34-42,95` — 10 hardcoded amd64 artefacts

```sh
34: wget -q https://downloads.datastax.com/cpp-driver/ubuntu/18.04/dependencies/libuv/v1.28.0/libuv1-dev_1.28.0-1_amd64.deb
…  (4 × wget, 4 × dpkg -i, 1 × rm — all _amd64.deb)
95: echo "JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" | sudo tee -a /etc/default/cassandra
```

Two independent defects. The `.deb`s 404/refuse on arm64, **and** the JVM path is arch-suffixed
(`java-8-openjdk-arm64` on ARM) so it would be wrong even if they installed. DataStax publishes no arm64
cpp-driver debs, so branching alone cannot fix this — it needs a source build or an explicit ARM guard in the
style of `webdriver.sh`. At minimum make `JAVA_HOME` derived:

```sh
JAVA_HOME=/usr/lib/jvm/java-8-openjdk-$(dpkg --print-architecture)
```

### C3. `chronograf.sh:22` — amd64 `.deb`, but arm64 exists · **CONFIRMED by probe** · ✅ FIXED

```sh
chronourl="https://dl.influxdata.com/chronograf/releases/chronograf_1.5.0.1_amd64.deb"
```

`dpkg -i` of an amd64 package on arm64 fails with *"package architecture (amd64) does not match system
(arm64)"*. Probed: `chronograf_1.5.0.1_arm64.deb` → **HTTP 200**. Same version, so this is a one-liner:

```sh
chronourl="https://dl.influxdata.com/chronograf/releases/chronograf_1.5.0.1_$(dpkg --print-architecture).deb"
```

### C4. `flyway.sh:23-27` — x86_64 JRE bundled in the tarball

```sh
wget https://repo1.maven.org/maven2/…/4.2.0/flyway-commandline-4.2.0-linux-x64.tar.gz
```

The download *succeeds* on ARM (the artefact exists — probed 200), which makes this deceptive: it fails later at
runtime because the bundled JRE is x86_64. Flyway 4.2.0 predates ARM support entirely.

> **Unverified:** I could not determine which Flyway version first ships a `linux-arm64` asset. Maven Central's
> latest (`13.3.0`) has neither `linux-x64` nor `linux-arm64` under the old naming, so the artefact layout has
> changed. Confirm against Flyway's release notes before pinning a version.

Interim option: drop the bundled JRE and use the `flyway-commandline-<v>.tar.gz` (no `-linux-*` suffix) with the
system JDK, which `openjdk-17.sh` already installs.

### C5. `r-base.sh:23` — stale suite · ✅ FIXED · **reclassified to bucket B**

```sh
# before
echo "deb [signed-by=…/r-project.gpg] https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/" | sudo tee …
# after
echo "deb [signed-by=…/r-project.gpg] https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" | sudo tee …
```

I originally listed a second defect here — that CRAN's Ubuntu binary repo is amd64-only. **That was wrong.**
Probed 2026-08-21:

| Suite | `Architecture: all` | `amd64` | `arm64` |
|---|---|---|---|
| `noble-cran40` | 134 | 96 | **74** |
| `jammy-cran40` | 248 | 186 | **71** |

CRAN ships arm64 for both suites, so there was never an ARM-specific problem here — only a stale hardcoded
release, which would have installed jammy packages on a noble box on *both* architectures. The one-line suite
fix resolves it completely and `r-base.sh` moves to bucket **B**.

### C6. `crystal.sh:24` — repo has no arm64 index

```sh
echo "deb [signed-by=…/crystal.gpg] https://dist.crystal-lang.org/apt crystal main" | sudo tee …
```

Probed: `…/dists/crystal/main/binary-amd64/Packages` → **200**; `binary-arm64` → **403**. A 403 rather than 404
is S3 permission semantics and not proof of absence, but combined with the amd64 index being public it strongly
indicates no arm64 index exists.

> **Verify on the guest** with `apt-cache policy crystal` before acting. If confirmed, Crystal's arm64 Linux
> builds are distributed as release tarballs rather than via this apt repo.

---

## 6. Bucket D — the one deliberate ARM carve-out, and why it didn't work · ✅ FIXED

`webdriver.sh:22-29`:

```sh
ARCH=$(arch)

if [[ "$ARCH" != "aarch64" ]]; then
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
    apt-get install -y /tmp/chrome.deb
    rm -f /tmp/chrome.deb
fi
```

**The intent is correct** — Google publishes no arm64 Chrome for Linux, and line 31 installs
`chromium-browser` (which builds for both) as the substitute. Three problems:

1. **`[[ ]]` is a bash keyword.** Under dash it is an unknown *command* → exit 127 → the `if` is false → **the
   else path is always taken**. On Intel that means Chrome is silently never installed. Demonstrated:
   ```
   $ dash -c 'if [[ "x86_64" != "aarch64" ]]; then echo THEN; else echo ELSE; fi'
   dash: 1: [[: not found
   ELSE          # should have been THEN
   ```
   This is currently latent — `webdriver.sh` is *not* inlined, so it runs under bash today. It becomes a real
   bug the moment anyone adds `webdriver` to the list in `use-homestead-features.sh`.
2. **The normalisation sed could never have caught it.** `use-homestead-features.sh:67`/`:99` matches
   `[[ "$ARCH" == "aarch64" ]]` — the `==` form only. `webdriver.sh` uses `!=`. And since commit `b18bbab`
   converted the inlined scripts to POSIX, **that sed now matches nothing at all** — it is a dead no-op giving
   false confidence.
3. **No log line.** Nothing tells the operator Chrome was skipped, so the arm64/amd64 divergence is invisible in
   build output. Worth one `echo`.

Fix: `if [ "$ARCH" != "aarch64" ]; then` … plus `else echo "arm64: skipping Google Chrome, using chromium-browser"`.

---

## 7. Second axis — dash compatibility

Separate from architecture, but it interacts: **an arch test written as a bashism silently picks the wrong
architecture**, which is why §6 sits in both axes.

| Script | Line | Construct | Effect under dash |
|---|---|---|---|
| `mariadb.sh` | 48-50 | `<<<` herestring | ✅ FIXED — was a parse failure; *no* line would execute |
| `webdriver.sh` | 25 | `[[ ]]` on `$ARCH` | ✅ FIXED — was silently taking the wrong branch |
| `neo4j.sh` | 41,44 | `SECONDS` + `[[ ]]` | ✅ FIXED — timeout was dead, loop could spin forever |
| `rvm.sh` | 27 | `source` | ✅ FIXED — was 127 as the last line, failing the provisioner |
| `php*.sh` × 12 | 15 | `[ "$X" == "disabled" ]` | ✅ FIXED — was taking the wrong branch |
| `postgres-9.5.sh` | 46 | `echo -e` | ✅ FIXED — was printing a literal `-e ` |

Verified across all 51 scripts **after the fixes**: `dash -n` and `bash -n` both pass on all 51 — zero parse
failures. Also swept and found **zero** occurrences of arrays, `declare`, `function`, `&>`, `+=`, `${var,,}`,
`${!var}`, `pushd`/`popd`, `set -o pipefail`, or process substitution.

*(Before the fixes, `dash -n` failed on `mariadb.sh` and six scripts carried runtime bashisms.)*

**False positive to ignore:** `postgres-9.5.sh:54` contains `[[` but it is the POSIX character class
`[[:digit:]]` inside a `grep` pattern — not a shell test. Do not "fix" it.

### What `b18bbab` already did

The commit *"adapt for bento run shell `dash`…"* migrated precisely the scripts that get inlined —
`golang.sh:25`, `mongodb.sh:25`, `minio.sh:22,27,68,80,91`, `rabbitmq.sh:31-34`, `postgres-pghashlib.sh`. **All
10 inlined scripts are dash-clean.** That is why the build works today.

The remaining work it left — 4 scripts plus the 12 `php*.sh` — was completed on 2026-08-21 (see §0). **The whole
`features/` tree is now dash-safe**, so any script may be added to the inlined set without a shell-compat
audit first.

> The commit message states *"dash does support some bashisms, e.g. `[[ ]]`"*. That is inverted — dash does
> **not** support `[[ ]]`; that is exactly why the migration was necessary. Worth correcting in a future commit
> message so the rationale isn't lost for the next reader.

---

## 8. Cross-cutting observations

1. **Five different arch idioms coexist**, sometimes in one file. `minio.sh` uses `arch|grep 'aarch64'` at `:22`
   for the server and `[ "$ARCH" = "aarch64" ]` at `:68` for the client. `rabbitmq.sh:31` uses the `arch|grep`
   form. `dragonflydb.sh` interpolates `$ARCH` directly. Consolidating on one helper would remove a whole class
   of future bugs.
2. **`dpkg --print-architecture` is used zero times** — despite being the correct tool for `deb [arch=…]` lines
   and `.deb` filenames, because it emits Debian arch names (`arm64`/`amd64`) directly. `arch` emits kernel
   names (`aarch64`/`x86_64`), forcing a translation that `rabbitmq.sh:31-34` performs by hand.
3. **`arch|grep` leaks to stdout.** It prints the matched `aarch64` into the build log mid-run. `grep -q` fixes.
4. **The safety-net sed is dead** (§6.2). Either delete it or replace it with a real lint step — `dash -n` over
   the selected features before inlining would have caught every item in §7.
5. **`mongodb.sh` has correct arch handling that nothing uses.** It is inlined into neither build (`grep -i
   mongo` over both settler scripts returns nothing). Separately it pins MongoDB **6.0** with
   `$(lsb_release -cs)` → `noble`, and 6.0 publishes no noble suite — so it would 404 on *both* architectures.
   That is an OS-version bug, not an ARM bug.

---

## 9. Appendix — settler inlining drift

Defects introduced by *how* features are inlined, not by the features themselves. Line numbers are
`scripts/arm.sh`; add +8 for `scripts/amd64.sh`.

| # | Where | Defect |
|---|---|---|
| 1 | all 10 blocks, e.g. `arm.sh:945` | `exit 0` → `echo 'skipping exit 0'` neuters **every** idempotency guard — each feature prints "already installed" then installs anyway |
| 2 | `arm.sh:1236` | `pm2`'s success `exit 0` is inside the retry loop. Neutered, the loop no longer breaks: a **successful** install runs `npm install -g pm2` 3×, sleeps twice, then logs a false `ERROR: pm2 installation failed after 3 attempts` |
| 3 | `arm.sh:1098,1144,1160` | minio's `exit 1`s are **indented**, so the anchored `s/^exit 1/…/` missed them. In a standalone script they end one feature; inlined they terminate the **entire** provisioning script ~line 1100 of 1542, silently skipping python, pm2, meilisearch, both openjdks, pghashlib and all cleanup |
| 4 | `amd64.sh:841` vs `:1312,:1326` | Base script installs PostgreSQL **16**; the shared feature block does `PGVER="${PGVER:-15}"` then `postgresql-plpython3-$PGVER` → **plpython3-15 against a PG16 server** on Intel. ARM is correct only because its two literals happen to match (`arm.sh:829 PGVER=15`) |
| 5 | `arm.sh:858` / `amd64.sh:865` | The **only** `[[ ]]` left in either generated file, outside the FEATURES block so the sed never touched it. On the ARM build this downloads the **amd64** Go tarball; it is then masked because the inlined `golang` feature redoes it correctly at `:951-965`. Net cost: a wasted ~80 MB download and a duplicated `PATH` line in `/home/vagrant/.profile` (`:867` and `:963`) |
| 6 | `arm.sh:1301-1343` | `build-customizations.sh` is inlined with **no `# … Feature (…)` marker** and its shebang stripped, so it reads as a continuation of the meilisearch block. Anyone auditing by grepping `# Homestead Feature (` misses 43 lines of package installs |
| 7 | `bin/use-homestead-features.sh:68,100` | The inliner is **not idempotent** — running twice appends a second full copy. `bin/build:79` compensates with `git checkout scripts/*.sh`, which means the tracked `arm.sh`/`amd64.sh` are simultaneously generated artefacts *and* tracked inputs. **Any hand-edit inside the FEATURES block is destroyed on the next build.** |

---

## 10. Open items — explicitly unverified

Stated here as unknown rather than guessed. Each needs one command on a running arm64 guest.

| Item | Question | How to settle |
|---|---|---|
| `eventstore.sh:33` | Does EventStore-OSS publish arm64 debs for noble? | `apt-cache policy eventstore-oss` after the packagecloud script runs |
| `heroku.sh:23` | Does the Heroku CLI apt channel carry arm64? | `apt-cache policy heroku`. Note it is a **flat** repo (`deb …/apt ./`), so `binary-*` path probes do not apply |
| `flyway.sh` | Which Flyway version first ships `linux-arm64`? | Flyway release notes — Maven Central's artefact naming has changed since 4.2.0 |
| `crystal.sh:24` | Is the 403 on `binary-arm64` absence or permissions? | `apt-cache policy crystal` on the guest |

**Method note.** Everything asserted as fact in §5 was confirmed by HTTP probe or by reading the file. During the
companion review of `scripts/arm.sh`, five package-availability concerns raised from memory (`sntp`,
`openjdk-8-jdk-headless`, `libmcrypt4`, and the arm64 pockets of `ppa:ondrej/php` and
`ppa:rabbitmq/rabbitmq-erlang`) turned out to be **wrong** once checked against the Launchpad API — all five are
present for noble/arm64. A sixth — the claim that CRAN's Ubuntu repo is amd64-only (§5-C5) — was likewise
**wrong**, caught only because the fix was probed before being applied. Hence the discipline here of separating
*probed* from *inferred*.

---

## 11. Suggested order of work

1. **Nothing here blocks the current build.** All 10 inlined scripts are dash-clean and arch-correct.
2. **Add a lint gate** — run `dash -n` over the selected features inside `use-homestead-features.sh` before
   inlining, and delete the dead sed at `:67`/`:99`. This prevents recurrence rather than fixing instances.
3. ~~**Fix the confirmed one-liners**~~ — **DONE 2026-08-21**, see §0: `openresty.sh:24` (path prefix),
   `chronograf.sh:22` (arch in filename), `webdriver.sh:25` (`[[` → `[`), `r-base.sh:23` (`$(lsb_release -cs)`).
4. ~~**Sweep the cheap dash fixes**~~ — **DONE 2026-08-21**, see §0: `php*.sh:15` × 12, `rvm.sh:27`,
   `mariadb.sh:48-50`, `neo4j.sh:41,44`, plus `postgres-9.5.sh:46`.
5. **Standardise on one arch helper** using `dpkg --print-architecture`, then migrate the five existing idioms
   onto it.
6. **Decide on `cassandra.sh` and `crystal.sh`** — upstream has no arm64 artefact, so these need either a source
   build or an explicit ARM guard. Do not paper over with a branch that 404s.
7. **Settler drift (§9) is separate work** and should wait until the running build completes.
