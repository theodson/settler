#!/usr/bin/env bash

#
# amd64
#
insertline=$(echo "$(grep -n '"provisioners":' ../bento/packer_templates/ubuntu/ubuntu-20.04-amd64.json | cut -d : -f 1)" | bc)
cat << COPY_FEATURE_FOLDER > "scripts/amd64.features-upload"
        {
            "inline": [
                "/usr/bin/mkdir -p /home/vagrant/.provision",
                "/usr/bin/chown -R vagrant:vagrant /home/vagrant/.provision"
            ],
            "type": "shell"
        },
        {
            "source": "../../../homestead/scripts/features/",
            "destination": "/home/vagrant/.provision",
            "type": "file"
        },
COPY_FEATURE_FOLDER
sed -i '' -e "${insertline}r scripts/amd64.features-upload" ../bento/packer_templates/ubuntu/ubuntu-20.04-amd64.json

insertline=$(echo "$(grep -n '# One last upgrade check' scripts/amd64.sh | cut -d : -f 1) -1" | bc)
echo > scripts/amd64.features
echo "# =========================== FEATURES START ============================" >> scripts/amd64.features 
for feature in golang rustc rabbitmq minio mailpit python pm2 meilisearch ohmyzsh; do
  echo "# Homestead Feature ($feature) " >> scripts/amd64.features
  cat  ../homestead/scripts/features/${feature}.sh >> scripts/amd64.features
done
echo "# ===========================  FEATURES END  ============================" >> scripts/amd64.features
sed -i '' -e '/usr\/bin\/env bash/d' scripts/amd64.features
sed -i '' -e "s/exit 0/echo 'skipping exit 0'/g" scripts/amd64.features
sed -i '' -e "${insertline}r scripts/amd64.features" scripts/amd64.sh


#
# ARM
#
insertline=$(echo "$(grep -n '"provisioners":' ../bento/packer_templates/ubuntu/ubuntu-20.04-arm64.json | cut -d : -f 1)" | bc)
cat << COPY_FEATURE_FOLDER > "scripts/arm.features-upload"
        {
            "inline": [
                "/usr/bin/mkdir -p /home/vagrant/.provision",
                "/usr/bin/chown -R vagrant:vagrant /home/vagrant/.provision"
            ],
            "type": "shell"
        },
        {
            "source": "../../../homestead/scripts/features/",
            "destination": "/home/vagrant/.provision",
            "type": "file"
        },
COPY_FEATURE_FOLDER
sed -i '' -e "${insertline}r scripts/arm.features-upload" ../bento/packer_templates/ubuntu/ubuntu-20.04-arm64.json

insertlinearm=$(echo "$(grep -n '# One last upgrade check' scripts/arm.sh | cut -d : -f 1) -1" | bc)
echo > scripts/arm.features
echo "# =========================== FEATURES START ============================" >> scripts/arm.features 
for feature in golang rustc rabbitmq minio mailpit python pm2 meilisearch ohmyzsh; do 
  echo "# Homestead Feature ($feature) " >> scripts/arm.features 
  cat  ../homestead/scripts/features/${feature}.sh >> scripts/arm.features
done
echo "# ===========================  FEATURES END  ============================" >> scripts/arm.features
sed -i '' -e '/usr\/bin\/env bash/d' scripts/arm.features
sed -i '' -e "s/exit 0/echo 'skipping exit 0'/g" scripts/arm.features
sed -i '' -e "${insertlinearm}r scripts/arm.features" scripts/arm.sh

/bin/ln -f scripts/amd64.sh ../bento/packer_templates/ubuntu/scripts/homestead.sh
/bin/ln -f scripts/arm.sh ../bento/packer_templates/ubuntu/scripts/homestead-arm.sh
