
このフォークでは、もともと H.265 をブラウザで再生するために作られた decoder_wasm に、MPEG2Video のデコード機能を追加しています。  
以下のドキュメントは、元の中国語のドキュメントを日本語に（ Google 翻訳を使い）翻訳し、また現状に合わせて変更したものです。

-----

# 1. はじめに

WebAssembly (Wasm) テクノロジーの助けを借りて、FFmpeg インターフェースが呼び出され、ブラウザー側で H.264 / H.265 / MPEG2Video ストリームから YUV データへのデコードが完了します。
全体的なプロセスは次のとおりです：

![Decode With FFmpeg and WASM](./doc/wasm.jpg "页面通过wasm调用FFmpeg流程图")

# 2. 依存関係

## 2.1 [WebAssembly (Wasm)](https://webassembly.org/)

公式ウェブサイトの定義によると、WebAssembly (wasm) は、ポータブルで、サイズが小さく、読み込みが速く、Web と互換性のある新しい形式です。wasm を介して、ネイティブコード（ C, C++ など）をブラウザーで実行できます。  
現在、wasm テクノロジーは主流のブラウザー（データソース: [Can I Use](https://www.caniuse.com/#search=WebAssembly)）によって広くサポートされています。

![Browser Suport For WASM](./doc/caniuse_wasm.jpg "主流浏览器对wasm的支持")

## 2.2 FFmpeg

FFmpeg は、デジタル音声と映像の記録、変換、およびストリームへの変換に使用できるオープンソースのコンピュータープログラムのセットです。LGPL または GPL ライセンスを採用します。音声と映像の録音、変換、ストリーミングのための完全なソリューションを提供します。  
私たちのコードは主にデコードに FFmpeg を使用しています。サイズを小さくするために、最終的にコンパイルされた wasm には、トリミングされた FFmpeg が含まれています。これには、主に次のライブラリが含まれています：

- libavcodec: コーデック（最も重要なライブラリ）
- libavutil: ツールライブラリ（ほとんどのライブラリはこのライブラリのサポートが必要です）
- libswscale: 映像のピクセルデータのフォーマット変換

# 3. 具体的な実現

## 3.1 インターフェース

コンパイルされた wasm ファイルは、4つの外部インターフェースを提供します：

- openDecoder: デコーダーを初期化します。
- decodeData: 受信した H.264 / H.265 / MPEG2Video ストリームデータをデコードします。
- flushDecoder: キャッシュされたデータをクリアします。
- closeDecoder: デコーダーを閉じます。

## 3.2 実装の詳細

デコードプロセスとデコードプロセスで使用される FFmpeg API を次の図に示します：

![decoder](./doc/decode_video.jpg "调用FFmpeg API解码流程")

## 3.3 使用方法

最終的なコンパイル結果は2つのファイルです。1つは FFmpeg ライブラリを含む wasm ファイルで、もう1つはグルーコード（ js ファイル）です。  
ページで js ファイルが参照されると、グルーコードは wasm をロードします。  
JavaScript と Wasm 間のデータ送受信：

```js
// 送信：
var cacheBuffer = Module._malloc(data.length);
Module.HEAPU8.set(data, cacheBuffer);
var ret = Module._decodeData(cacheBuffer, data.length, pts);

// 受信：
var videoSize = 0;
var videoCallback = Module.addFunction(function (addr_y, addr_u, addr_v, stride_y, stride_u, stride_v, width, height, pts) {
    console.log("[%d]In video callback, size = %d * %d, pts = %d", ++videoSize, width, height, pts)
    let out_y = HEAPU8.subarray(addr_y, addr_y + stride_y * height)
    let out_u = HEAPU8.subarray(addr_u, addr_u + (stride_u * height) / 2)
    let out_v = HEAPU8.subarray(addr_v, addr_v + (stride_v * height) / 2)
    let buf_y = new Uint8Array(out_y)
    let buf_u = new Uint8Array(out_u)
    let buf_v = new Uint8Array(out_v)
    let data = new Uint8Array(buf_y.length + buf_u.length + buf_v.length)
    data.set(buf_y, 0)
    data.set(buf_u, buf_y.length)
    data.set(buf_v, buf_y.length + buf_u.length)
    var obj = {
        data: data,
        width,
        height
    }
    displayVideoFrame(obj);
});

// コーデックの種類: 0 - H.264, 1 - H.265, 2 - MPEG2Video
var codecType = 1;
// openDecoder() メソッドを介して C レイヤーにコールバックを渡し、C レイヤーでこれを呼び出す必要があります。
var ret = Module._openDecoder(codecType, videoCallback, LOG_LEVEL_WASM)
```

# 4 コンパイル

## 4.1 Emscripten をインストールする

インストール手順については、[公式ドキュメント](https://emscripten.org/docs/getting_started/downloads.html) を参照してください。現在、Windows、MacOS、および Linux をサポートしています。

推奨バージョン: 1.38.45, コンパイルと実行に問題はありません。

## 4.2 FFmpeg をダウンロードする

```bash
mkdir goldvideo
cd goldvideo
git clone https://git.ffmpeg.org/ffmpeg.git
cd ffmpeg
git checkout -b 4.1 origin/release/4.1
```

ここで 4.1 ブランチをチェックアウトします。

## 4.3 この記事のコードをダウンロードする

FFmpeg ディレクトリとコードディレクトリが同じフォルダ階層にあることを確認してください。

```bash
git clone http://github.com/tsukumijima/decoder_wasm.git
cd decoder_wasm

ディレクトリ構造：

├─goldvideo
│  ├─ffmpeg
│  ├─decoder_wasm
```

## 4.4 コンパイル

次のいずれかのコマンドを選択して実行します。

```bash
./build_decoder.sh             // H.264 / H.265 / MPEG2Video のデコードをサポート
./build_decoder_h264.sh        // H.264 のデコードをサポート
./build_decoder_h265.sh        // H.265 のデコードをサポート
./build_decoder_mpeg2video.sh  // MPEG2Video のデコードをサポート
```

# 5. テスト

## 5.1 WebGL

デコードした映像は Canvas を使用して描画しますが、デフォルトの 2d モードでは RGB 形式でしか描画できません。

FFmpeg でデコードされたビデオデータは YUV 形式です。レンダリングする場合は、色空間変換を実行する必要があります。変換用に、FFmpeg の libswscale モジュールを使用できます。<br>
パフォーマンスを向上させるために、WebGL はハードウェアアクセラレーションに使用されます。主に [YUV-Webgl-Video-Player](https://github.com/p4prasoon/YUV-Webgl-Video-Player) を参考にしていますが、いくつかの変更が加えられています。

## 5.2 サーバーの起動：

```bash
npm install
npm start
```
## 5.3 テストページ：

### 注意

- PTS のない生の映像ファイルを再生するためか、再生中に一部のフレームがドロップする場合があります。
- デコーダーの種類が正しく設定されないため、ファイルをドラッグ&ドロップで設定しないでください。

```
http://localhost:3000/test/main.html
```

# 6. 参考項目

[WasmVideoPlayer](https://github.com/sonysuqin/WasmVideoPlayer).
