export function init(ctx, html) {
  ctx.importJS("https://cdn.jsdelivr.net/npm/hls.js@latest");
  ctx.root.innerHTML = html;

  console.log("loaded");

  let video1 = document.getElementById("source"),
    video2 = document.getElementById("output"),
    spinner = document.getElementById("spinner"),
    fileProc = document.getElementById("file-proc"),
    stop = document.getElementById("stop"),
    isReady = false;

  navigator.mediaDevices
    .getUserMedia({
      video: { width: 640, height: 480 },
      audio: false,
    })
    .then((stream) => {
      video1.srcObject = stream;
      spinner.style.visibility = "hidden";
      video2.style.visibility = "hidden";

      const options = { mimeType: "video/webm; codecs=vp8" };
      let mediaRecorder = new MediaRecorder(stream);

      mediaRecorder.ondataavailable = async ({ data }) => {
        if (!isReady) return;
        if (data.size > 0) {
          console.log(data.size);
          const buffer = await data.arrayBuffer();
          ctx.pushEvent("chunk", [{}, buffer]);
        }
      };
      fileProc.onclick = () => {
        isReady = true;
        if (mediaRecorder.state == "inactive") mediaRecorder.start(1_000);
        spinner.style.visibility = "visible";
      };

      stop.onclick = () => {
        mediaRecorder.stop();
        ctx.pushEvent("stop", {});
      };

      ctx.handleEvent("playlist_ready", handleHls);
      function handleHls() {
        spinner.style.visibility = "hidden";
        video2.style.visibility = "visible";
        let hls = new Hls();
        if (Hls.isSupported()) {
          hls.loadSource("http://localhost:4001/hls/playlist.m3u8");
          hls.attachMedia(video2);
          hls.on(Hls.Events.MANIFEST_PARSED, () => {
            video2.play();
          });
          hls.on(Hls.Events.ERROR, (event, data) => {
            console.log(event, data);
          });
          // Safari can play this natively
        } else if (video2.canPlayType("application/vnd.apple.mpegurl")) {
          video2.src = "/output/playlist.m3u8";
          video2.addEventListener("loadedmetadata", () => {
            video2.play();
          });
        }
      }
    });
}
