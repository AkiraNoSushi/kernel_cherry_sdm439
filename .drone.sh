#!/bin/bash

# Setting up build environment...
apt-get install unzip p7zip-full curl python2 -yq
# We download repo as zip file because it's faster than cloning it with git
wget -nv https://github.com/kdrag0n/proton-clang/archive/master.zip
unzip master.zip

# Build
make O=out ARCH=arm64 cherry-sdm439_defconfig
PATH="$(pwd)/proton-clang-master/bin:${PATH}"
make -j$(nproc --all) O=out ARCH=arm64 \
                      CC=clang \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi-

# Sign Prima module
aarch64-linux-gnu-strip --strip-unneeded --strip-debug out/drivers/staging/prima/wlan.ko
out/scripts/sign-file sha512 out/certs/signing_key.pem out/certs/signing_key.x509 out/drivers/staging/prima/wlan.ko

# Build flashable zip
cp out/arch/arm64/boot/dtbo.img AnyKernel3/
cp out/drivers/staging/prima/wlan.ko AnyKernel3/pronto_wlan.ko
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
