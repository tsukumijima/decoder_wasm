
echo "Beginning Build:"
rm -r ffmpeg
mkdir -p ffmpeg
cd ../ffmpeg
make clean

# configure ffmpeg with Emscripten
# ref: https://itnext.io/build-ffmpeg-webassembly-version-ffmpeg-js-part-3-ffmpeg-js-v0-1-0-transcoding-avi-to-mp4-f729e503a397
export PATH="$PATH:$EMSDK/upstream/bin"
CFLAGS="-s USE_PTHREADS -O3 -msse -msse2 -msse3 -mssse3 -msse4.1 -msse4.2 -mavx -msimd128"
emconfigure ./configure --cc="emcc" --cxx="em++" --objcc="emcc" --dep-cc="emcc" \
    --nm="llvm-nm" --ar="emar" --ranlib="emranlib" --extra-cflags="$CFLAGS" --extra-cxxflags="$CFLAGS" \
    --prefix=$(pwd)/../decoder_wasm/ffmpeg --enable-cross-compile --target-os=none --arch=x86_32 --cpu=generic \
    --enable-gpl --enable-version3 --disable-avdevice --disable-avformat --disable-swresample --disable-postproc --disable-avfilter \
    --disable-programs --disable-logging --disable-everything \
    --disable-ffplay --disable-ffprobe --disable-asm --disable-doc --disable-devices --disable-network \
    --disable-hwaccels --disable-parsers --disable-bsfs --disable-debug --disable-protocols --disable-indevs --disable-outdevs \
    --enable-decoder=h264 --enable-parser=h264 \
    --enable-decoder=hevc --enable-parser=hevc \
    --enable-decoder=mpeg2video --enable-parser=mpegvideo

# build ffmpeg
emmake make -j4
emmake make install

# build libffmpeg.wasm
cd ../decoder_wasm
./build_decoder_wasm.sh
