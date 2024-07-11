# HLS with Elixir

## What?

We are going to use [HTTP Live Streaming](https://en.wikipedia.org/wiki/HTTP_Live_Streaming).

`HLS` is a streaming protocol developed by Apple to deliver media content over the internet using HTTP. It breaks the overall stream into a sequence of small HTTP-based file downloads, each download loading one short chunk of an overall potentially unbounded transport stream. It uses a (unique) "playlist" file that describes the "segments" files to be played. It uses a dedicated library Once these files are available for reading (in the browser), the library <mark>`hls.js`</mark> will download the playlist and consequently segments to be played. It handles entirely the playback process. `Elixir` will serve these files.

:exclamation: This protocole has **high latency**: you will experience up to 20 seconds delay.

Our job here is to:

- capture the built-in webcam stream
- transform the images server-side. We ran the "hello world" of computer vision, namely **face detection** with the `Haar Cascade model`. This is powered by [Evision](https://github.com/cocoa-xu/evision) (<mark>[OpenCV](https://docs.opencv.org/4.10.0/)</mark>). The model is present by default in the source code of `Evision` and has a loader for it.
- send the transformed images back to the browser. They are played back by the Javacript library `hls.js`. It is based on the [MediaSource API](https://developer.mozilla.org/en-US/docs/Web/API/MediaSource).

This relies heavily on <mark>[FFmpeg](https://ffmpeg.org/ffmpeg-formats.html#hls-1)</mark> to get frames from the input video source and build HLS segments and the playlist.

## How?

This is a `Plug` app which aims to be minimal. It illustrates HTTP Live Streaming - <mark>[HLS](https://github.com/video-dev/hls.js)</mark>.

We run a tpc listener on port 4000 with `Bandit` to communicate with the browser.

We use a _raw WebSocket_ in the browser. The backend uses the library [websock_adapter](https://github.com/phoenixframework/websock_adapter).
We use it to send binary data (an `ArryBuffer`) from the browser to the Elixir backend. Check [this blog](https://kobrakai.de/kolumne/bare-websockets).
We securized the WS connection with a CSRFToken.

We have a `Plug` router that:

- serves the static files: the (unique) HTML page, the associated Javascript module and the HLS files,
- handles the `WebSocket` connection.

We run `FFmpeg` as **"kept alive"** with `ExCmd.Process`. This is crucial for the process.

We run a **file watcher process** with `file_system`. It will detect when `FFmpeg` will have built the HLS playlist and segments.

## Run it

From this directory, do:

```elixir
open http://localhost:4000 && mix run --no-halt
```

:exclamation: We need to have `FFmpeg` installed but also `fsevent` on MacOS or `inotify` for Linux on which depends `FlieSystem`.

[TODO] A livebook

:exclamation: You might encounter the error "segmentation fault". No further explanation on this.

## Process flow

The browser will ask to control your webcam.

Once you click on "start", a WebSocket connection is instantiated with the backend.
The browser will produce video chunks and send them to the server.
The server will extract all the frames, save them into files, pass the file to the Evision process for face detection.
The frames will be glued altogether (respecting the order) to produce video chunks ready for the browser to consume them.
They is a file watching process to detect when the playlist is ready, and we pass this message to the browser.
The HLS Javascript library will then ready the playlist and download on a regular basis the new segments it needs.

```mermaid
graph TD
    F -->|mediaRecorder <br>send video chunk| A
    A -- WebSocketHandler.init --> A
    A[WebSocketHandler] -->|ffmpeg_capture: <br>make frames| B[WebSocketHandler]
    B -->|send: process_queue| C[WebSocketHandler]
    C -->|send: ffmpeg_rebuild<br>make segments & playlist| E[WebSocketHandler]
    E -->|send: playlist_ready| F[Browser]

    G[FileWatcher] -->|send: playlist_created| E[WebSocketHandler]
    F -- hls.js <br> GET playlist / segments--> H[Elixir / Plug]
```

### Notes on the code

#### The "web router" module

We defined four routes.

The root "/" sends the HTML text. It is parsed to add a CSRFToken.

The "/js/main.js" route sends the Javascript file when the browser calls it.

The ""/hls/:file" route sends the HLS segments when the browser calls them.

The "/socket" route upgrade to a WebSocket connection after the token validation (comparison between the token saved in the session and the one received in the query string).

#### The "controller" module

This module serves the files. Since we want to pass a "CSRFToken" to the Javascript, w use `EEX.eval_file` to parse the "index.html.heex" text.

```elixir
def serve_homepage(conn, %{csrf_token: token}) do
html = EEx.eval_file("./priv/index.html.heex", csrf_token: token)
Plug.Conn.send_resp(conn, 200, html)
end
```

#### The "file watcher" module

It essentially uses `FileSystem`. We declare which folder we want ot monitor, and the detected changes emit an event that we exploit to send to the caller process (the WebSocketHandler) a message.
We monitor the creation of the "playlist.m3u8" file.

```mermaid
graph LR
    A[FileWatcher.init] --pid = FileSystem.start_link <br>dirs: priv/hls <br>  --> D[FileSystem.subscribe pid]

    E[handle_info] -- :file_event <br> .m3u8--> G[send: playlist_created<br> to WebSocketHandler]
```

#### The "ffmpeg processor" module

It runs `FFmpeg` as "kept alive" processes via `ExCmd`. This is crucial as we pipe the stdin to FFmpeg.

When we receive video chunks in binary form via the WebSocket (approx 300KB, depending on the height/width of your video HTMLElement), we pass it to FFmpeg to extract all the frames, at 30 fps.
Each frame is saved into a file (approx 10kB).

The other FFmpeg process is when we rebuild HSL video chunks from the transformed frames.
FFmpeg will update a playlist and produce HSL segments. The FFmpeg process must not die in order not to append "#EXT-X-ENDLIST" at the end of the playlist.

The general form of a FFmpeg command is:

```
ffmpeg [GeneralOptions] [InputFileOptions] -i input [OutputFileOptions] output
```

#### The "image processor" module

We use `Evision` to detect faces and draw rectangles around the region of interest found.

:exclamation: When you run the code, you will see that the Haar Cascade models produces a lot of false positives.

#### The "websocket handler" module

A visualisation may perhaps help to understand.

```mermaid
graph LR

   E[handle_in: binary_msg] --> F[FFmpeg process<br> save frames into files]
   F -- craete files <br>priv/input--> G[send: ffmpeg_process]

   H[handle_info: ffmpeg_process] --read files <br>priv/input--> J[Enqueue new files]
   J --> K[send: process_queue]

   L[handle_info: process_queue] --> M[Process files with Evision<br>
       detect_and_draw_faces]
   M -- create files<br>priv/output--> O[send: ffmpeg_rebuild <br> when queue empty]

   P[handle_info: ffmpeg_rebuild when chunk_id == 5] -- files in<br>priv/output--> Q[Pass files to FFmpeg segment process]
   Q--> R[files in priv/hls]

   UU[FileWatcher] -- event<br>playlist created-->U[handle_info: playlist_created, init: true]
   U --> V[send playlist_ready to browser]
```

##### Instantiate the WebSocket handler

When the browser initiates a WebSocket connection, the backend will respond with:

```mermaid
graph TD
    A[WebSocketHandler.init] --> B[FileWatcher]
    A --> C[FFmpegProcessor]
    C --> D[FFmpeg Capture Process]
    C --> E[FFmpeg Rebuild Process]
    A --> F[load_haar_cascade]
    D --> G[State]
    E-->G
    F-->G
```

### Javascript

For clarity, the Javascript module is separated into its own file. It is served by Elixir/Plug.

We load `hls.js` from a CDN:

```html
<script src="https://cdn.jsdelivr.net/npm/hls.js@latest" defer></script>
```

We need to use `DOMContentLoaded`, so the "main.js" module starts with:

```
window.addEventListener('DOMContentLoaded', ()=> {...})
```

We use the WebSocket API:

```js
let socket = new WebSocket(
  `ws://localhost:4000/socket?csrf_token=${csrfToken}`
);
```

We use the WebRTC `getUserMedia` to display the built-in into a `<video>` element:

```js
let stream = await navigator.mediaDevices.getUserMedia({
  video: { width: 640, height: 480 },
  audio: false,
});

video1.srcObject = stream;
```

We use the `MediaRecorder` API to record the streams and push chunks every 1000ms to the connected server via the WebSocket:

```js
let mediaRecorder = new MediaRecorder(stream);

mediaRecorder.ondataavailable = async ({ data }) => {
  if (!isReady) return;
  if (data.size > 0) {
    console.log(data.size);
    const buffer = await data.arrayBuffer();
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(buffer);
    }
  }
};
mediaRecorder.start(1_000);
```
