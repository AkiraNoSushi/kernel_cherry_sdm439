#!/bin/bash

# Setting up build environment...
apt-get install unzip p7zip-full curl python2 binutils-aarch64-linux-gnu aria2 -yq
# We download repo as zip file because it's faster than cloning it with git
aria2c https://github.com/Reinazhard/aosp-clang/archive/refs/heads/master.zip
unzip -qq aosp-clang-master.zip
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/ --depth=1 --single-branch
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/ --depth=1 --single-branch

# Build
make O=out ARCH=arm64 cherry-sdm439_defconfig
PATH="$(pwd)/aosp-clang-master/bin:/$(pwd)/aarch64-linux-android-4.9/bin:$(pwd)/arm-linux-androideabi-4.9/bin:${PATH}"
make -j$(nproc --all) O=out ARCH=arm64 \
                      CC=clang \
                      CROSS_COMPILE=aarch64-linux-android- \
                      CROSS_COMPILE_ARM32=arm-linux-androideabi- \
                      CLANG_TRIPLE=aarch64-linux-gnu-

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
