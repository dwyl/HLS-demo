defmodule ImageProcessor do
  @moduledoc """
  Loads the Haar Cascade Classifier and detects faces in images
  """
  
  
  def load_haar_cascade do
    haar_path =
      Path.join(
        :code.priv_dir(:evision),
        "share/opencv4/haarcascades/haarcascade_frontalface_default.xml"
      )

    Evision.CascadeClassifier.cascadeClassifier(haar_path)
  end

  def detect_and_draw_faces(file, face_detector) do
    input_path = Path.join("priv/input", file)
    output_path = Path.join("priv/output", file)

    frame =
      Evision.imread(input_path)

    # convert to grey-scale
    grey_img =
      Evision.cvtColor(frame, Evision.ImreadModes.cv_IMREAD_GRAYSCALE())

    # detect faces
    faces =
      Evision.CascadeClassifier.detectMultiScale(face_detector, grey_img)

    # draw rectangles found on the original frame
    result_frame =
      Enum.reduce(faces, frame, fn {x, y, w, h}, mat ->
        Evision.rectangle(mat, {x, y}, {x + w, y + h}, {0, 255, 0}, thickness: 2)
      end)

    Evision.imwrite(output_path, result_frame)
    :ok = File.rm!(input_path)
  end
end
