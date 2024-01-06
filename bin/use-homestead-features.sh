#!/usr/bin/env bash

packer_template_amd64=../bento/packer_templates/ubuntu/ubuntu-20.04-amd64.json
packer_template_arm64=../bento/packer_templates/ubuntu/ubuntu-20.04-arm64.json

echo "
SETTLER_VERSION='$SETTLER_VERSION'
HOMESTEAD_VERSION='$HOMESTEAD_VERSION'
"

#
# Temporary fix for failing ISO ubuntu-20.04.5 until ubuntu-20.04.6-live-server-amd64 is available in bento. 
# 20.04.6 is released but bento has not yet updated - must refer to old-releases site for 20.04.5 
#
if true; then
  # use 20.04.6
  sed -i 's/ubuntu-20.04.5-live-server-amd64.iso/ubuntu-20.04.6-live-server-amd64.iso/' $packer_template_amd64
  sed -i 's/sha256:5035be37a7e9abbdc09f0d257f3e33416c1a0fb322ba860d42d74aa75c3468d4/sha256:b8f31413336b9393ad5d8ef0282717b2ab19f007df2e9ed5196c13d8f9153c8b/' $packer_template_amd64
else
  # use 20.04.5
  sed -i 's/releases.ubuntu.com/old-releases.ubuntu.com/' $packer_template_amd64
  sed -i 's/focal/releases\/20.04.5/' $packer_template_amd64
fi

#
# amd64
#
insertline=$(echo "$(grep -n '"provisioners":' $packer_template_amd64 | cut -d : -f 1)" | bc)
cat << COPY_FEATURE_FOLDER > "scripts/amd64.features-upload"
        {
            "inline": [
                "/usr/bin/mkdir -p /home/vagrant/.homestead-scripts /home/vagrant/.provision-scripts",
                "/usr/bin/chown -R vagrant:vagrant /home/vagrant/.homestead-scripts /home/vagrant/.provision-scripts"
            ],
            "type": "shell"
        },
        {
            "source": "../../../homestead/scripts/",
            "destination": "/home/vagrant/.homestead-scripts",
            "type": "file"
        },
        {
            "source": "../../../settler-provision-scripts/",
            "destination": "/home/vagrant/.provision-scripts",
            "type": "file"
        },
COPY_FEATURE_FOLDER
sed -i -e "${insertline}r scripts/amd64.features-upload" $packer_template_amd64

insertline=$(echo "$(grep -n '# One last upgrade check' scripts/amd64.sh | cut -d : -f 1) -1" | bc)
echo > scripts/amd64.features
echo -e "\n# =========================== FEATURES START ============================\n" >> scripts/amd64.features 
echo "

export SETTLER_VERSION='$SETTLER_VERSION'
export HOMESTEAD_VERSION='$HOMESTEAD_VERSION'

"
for feature in golang rustc rabbitmq minio mailpit python pm2 meilisearch; do
  echo -e "\n# Homestead Feature ($feature) \n" >> scripts/amd64.features
  cat  ../homestead/scripts/features/${feature}.sh >> scripts/amd64.features
done

cat  ../settler-provision-scripts/osupdate.sh >> scripts/amd64.features
  
for feature in openjdk-17 openjdk-8 postgres-pghashlib; do
  echo -e "\n# Extra Homestead Feature ($feature) \n" >> scripts/amd64.features
  cat  ../settler-provision-scripts/features/${feature}.sh >> scripts/amd64.features
done
echo -e "\n# ===========================  FEATURES END  ============================\n" >> scripts/amd64.features
sed -i -e '/usr\/bin\/env bash/d' scripts/amd64.features
sed -i -e "s/exit 0/echo 'skipping exit 0'/g" scripts/amd64.features
sed -i -e "${insertline}r scripts/amd64.features" scripts/amd64.sh


#
# ARM
#
insertline=$(echo "$(grep -n '"provisioners":' $packer_template_arm64 | cut -d : -f 1)" | bc)
cat << COPY_FEATURE_FOLDER > "scripts/arm.features-upload"
        {
            "inline": [
                "/usr/bin/mkdir -p /home/vagrant/.homestead-scripts /home/vagrant/.provision-scripts",
                "/usr/bin/chown -R vagrant:vagrant /home/vagrant/.homestead-scripts /home/vagrant/.provision-scripts"
            ],
            "type": "shell"
        },
        {
            "source": "../../../homestead/scripts/",
            "destination": "/home/vagrant/.homestead-scripts",
            "type": "file"
        },
        {
            "source": "../../../settler-provision-scripts/",
            "destination": "/home/vagrant/.provision-scripts",
            "type": "file"
        },
COPY_FEATURE_FOLDER
sed -i -e "${insertline}r scripts/arm.features-upload" $packer_template_arm64

insertlinearm=$(echo "$(grep -n '# One last upgrade check' scripts/arm.sh | cut -d : -f 1) -1" | bc)
echo > scripts/arm.features
echo -e "\n# =========================== FEATURES START ============================\n" >> scripts/arm.features
echo "

export SETTLER_VERSION='$SETTLER_VERSION'
export HOMESTEAD_VERSION='$HOMESTEAD_VERSION'

" 
for feature in golang rustc rabbitmq minio mailpit python pm2 meilisearch; do 
  echo -e "\n# Homestead Feature ($feature) \n" >> scripts/arm.features 
  cat  ../homestead/scripts/features/${feature}.sh >> scripts/arm.features
done

cat  ../settler-provision-scripts/osupdate.sh >> scripts/amd64.features
  
for feature in openjdk-17 openjdk-8 postgres-pghashlib; do
  echo -e "\n# Extra Homestead Feature ($feature) \n" >> scripts/amd64.features
  cat  ../settler-provision-scripts/features/${feature}.sh >> scripts/amd64.features
done
echo -e "\n# ===========================  FEATURES END  ============================\n" >> scripts/arm.features
sed -i -e '/usr\/bin\/env bash/d' scripts/arm.features
sed -i -e "s/exit 0/echo 'skipping exit 0'/g" scripts/arm.features
sed -i -e "${insertlinearm}r scripts/arm.features" scripts/arm.sh

/bin/ln -f scripts/amd64.sh ../bento/packer_templates/ubuntu/scripts/homestead.sh
/bin/ln -f scripts/arm.sh ../bento/packer_templates/ubuntu/scripts/homestead-arm.sh
