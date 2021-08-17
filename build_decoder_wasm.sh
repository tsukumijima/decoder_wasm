
if [ $# != 1 ]; then
    suffix=""
else
    suffix="_$1"
fi

rm -rf dist/libffmpeg$suffix.wasm dist/libffmpeg$suffix.js
export TOTAL_MEMORY=67108864
export EXPORTED_FUNCTIONS="[ \
    '_openDecoder', \
	'_flushDecoder', \
	'_closeDecoder', \
    '_decodeData', \
    '_main'
]"

echo "Running Emscripten..."
emcc decode_video.c ffmpeg/lib/libavcodec.a ffmpeg/lib/libavutil.a ffmpeg/lib/libswscale.a \
    -O3 -msse -msse2 -msse3 -mssse3 -msse4.1 -msse4.2 -mavx -msimd128 \
    -I "ffmpeg/include" \
    -s WASM=1 \
    -pthread -s USE_PTHREADS=1 -s PROXY_TO_PTHREAD=1 \
    -s TOTAL_MEMORY=${TOTAL_MEMORY} \
   	-s EXPORTED_FUNCTIONS="${EXPORTED_FUNCTIONS}" \
   	-s EXPORTED_RUNTIME_METHODS="['addFunction']" \
		-s RESERVED_FUNCTION_POINTERS=14 \
		-s FORCE_FILESYSTEM=1 \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s WASM_MEM_MAX=512MB \
    -o dist/libffmpeg$suffix.js

echo "Finished Build"
