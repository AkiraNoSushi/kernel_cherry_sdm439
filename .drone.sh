#!/bin/bash

# Setting up build environment...
apt-get install unzip p7zip-full curl python2 binutils-aarch64-linux-gnu wget binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi libncurses5 -yq
# We download repo as zip file because it's faster than cloning it with git
wget https://github.com/ThankYouMario/proprietary_vendor_qcom_sdclang/archive/refs/heads/ruby-12.zip
unzip -qq ruby-12.zip

# Build
make O=out ARCH=arm64 cherry-sdm439_defconfig
PATH="$(pwd)/proprietary_vendor_qcom_sdclang-ruby-12/bin:${PATH}"
make -j$(nproc --all) O=out ARCH=arm64 \
                      CC=clang \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \

# Build flashable zip
cp out/arch/arm64/boot/dtbo.img AnyKernel3/
cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3/
zipfile="./out/CherryKernel_$(date +%Y%m%d-%H%M).zip"
7z a -mm=Deflate -mfb=258 -mpass=15 -r $zipfile ./AnyKernel3/*

# Send flashable zip to Telegram channel
escape() {
    echo $1 | sed -Ee "s/([^a-zA-Z\s0-9])/\\\\\1/g"
}

FILE_CAPTION=$(cat << EOL
*Branch:* $(escape $DRONE_BRANCH)
*Commit:* [$(echo $DRONE_COMMIT | cut -c -7)]($(escape $DRONE_COMMIT_LINK))
EOL
)
curl -F "document=@${zipfile}" --form-string "caption=${FILE_CAPTION}" "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument?chat_id=${TELEGRAM_CHAT_ID}&parse_mode=MarkdownV2"
