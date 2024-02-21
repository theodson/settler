#!/usr/bin/env bash

packer_builder=../bento/packer_templates/pkr-builder.pkr.hcl
packer_vars=../bento/packer_templates/pkr-variables.pkr.hcl

echo "
SETTLER_VERSION='$SETTLER_VERSION'
HOMESTEAD_VERSION='$HOMESTEAD_VERSION'
"


insertline=$(echo "$(grep -n '# Linux Shell scipts' $packer_builder | cut -d : -f 1)" | bc)
cat << COPY_FEATURE_FOLDER > "scripts/amd64.features-upload"
  provisioner "shell" {
    inline = [
      "/usr/bin/mkdir -p /home/vagrant/.homestead-scripts /home/vagrant/.provision-scripts",
      "/usr/bin/chown -R vagrant:vagrant /home/vagrant/.homestead-scripts /home/vagrant/.provision-scripts"
    ]
  }
  
  provisioner "file" {
    source = "../homestead/scripts/"
    destination = "/home/vagrant/.homestead-scripts"
  }
  
COPY_FEATURE_FOLDER
sed -i -e "${insertline}r scripts/amd64.features-upload" $packer_builder

#
# AMD64
#
insertline=$(echo "$(grep -n '# One last upgrade check' scripts/amd64.sh | cut -d : -f 1) -1" | bc)
echo > scripts/amd64.features
echo -e "\n# =========================== FEATURES START ============================\n" >> scripts/amd64.features 
echo "

export SETTLER_VERSION='$SETTLER_VERSION'
export HOMESTEAD_VERSION='$HOMESTEAD_VERSION'

" >> scripts/amd64.features 
for feature in golang rustc rabbitmq minio python pm2 meilisearch; do
  echo -e "\n# Homestead Feature ($feature) \n" >> scripts/amd64.features
  cat  ../homestead/scripts/features/${feature}.sh >> scripts/amd64.features
done

cat scripts/build-customizations.sh >> scripts/amd64.features
  
for feature in openjdk-17 openjdk-8 postgres-pghashlib; do
  echo -e "\n# Custom Homestead Feature ($feature) \n" >> scripts/amd64.features
  cat  ../homestead/scripts/features/${feature}.sh >> scripts/amd64.features
done
echo -e "\n# ===========================  FEATURES END  ============================\n" >> scripts/amd64.features
sed -i -e '/usr\/bin\/env bash/d' scripts/amd64.features
sed -i -e "s/exit 0/echo 'skipping exit 0'/g" scripts/amd64.features
sed -i -e "${insertline}r scripts/amd64.features" scripts/amd64.sh


#
# ARM
#
insertlinearm=$(echo "$(grep -n '# One last upgrade check' scripts/arm.sh | cut -d : -f 1) -1" | bc)
echo > scripts/arm.features
echo -e "\n# =========================== FEATURES START ============================\n" >> scripts/arm.features
echo "

export SETTLER_VERSION='$SETTLER_VERSION'
export HOMESTEAD_VERSION='$HOMESTEAD_VERSION'

" >> scripts/arm.features
for feature in golang rustc rabbitmq minio python pm2 meilisearch; do 
  echo -e "\n# Homestead Feature ($feature) \n" >> scripts/arm.features 
  cat  ../homestead/scripts/features/${feature}.sh >> scripts/arm.features
done

cat scripts/build-customizations.sh >> scripts/arm.features
  
for feature in openjdk-17 openjdk-8 postgres-pghashlib; do
  echo -e "\n# Custom Homestead Feature ($feature) \n" >> scripts/arm.features
  cat  ../homestead/scripts/features/${feature}.sh >> scripts/arm.features
done
echo -e "\n# ===========================  FEATURES END  ============================\n" >> scripts/arm.features
sed -i -e '/usr\/bin\/env bash/d' scripts/arm.features
sed -i -e "s/exit 0/echo 'skipping exit 0'/g" scripts/arm.features
sed -i -e "${insertlinearm}r scripts/arm.features" scripts/arm.sh

/bin/ln -f scripts/amd64.sh ../bento/packer_templates/scripts/ubuntu/homestead_amd64.sh
/bin/ln -f scripts/arm.sh ../bento/packer_templates/scripts/ubuntu/homestead_arm.sh
