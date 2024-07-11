
defmodule FFmpegProcessor do
  @moduledoc false

  def start(frame_rate, resolution, duration) do
    frame_pattern = "priv/input/test_%05d.jpg"

    build_frames =
      ~w(ffmpeg -loglevel debug -i pipe:0 -framerate #{frame_rate} -video_size #{resolution} -thread_type slice #{frame_pattern})

    {:ok, pid_capture} =
      ExCmd.Process.start_link(build_frames)

    playlist = Path.join("priv/hls", "playlist.m3u8")
    segment = Path.join("priv/hls", "segment_%03d.ts")
    ffmpeg_rebuild_cmd = ~w(ffmpeg -loglevel info 
			-f image2pipe -framerate #{frame_rate}
			-i pipe:0 -c:v libx264 
			-preset veryfast 
			-f hls 
			-hls_time #{duration}
			-hls_list_size 4 
			-hls_playlist_type event
			-hls_flags append_list 
			-hls_segment_filename #{segment} 
			#{playlist}
		)

    {:ok, pid_segment} =
      ExCmd.Process.start_link(ffmpeg_rebuild_cmd)

    {pid_capture, pid_segment}
  end
end

##################################################################################
# ffmpeg [GeneralOptions] [InputFileOptions] -i input [OutputFileOptions] output #
##################################################################################
