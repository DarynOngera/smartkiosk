defmodule SmartKioskWeb.LocalUploads do
  @moduledoc """
  Stores LiveView uploads under `priv/static/uploads` and returns public URLs.
  """

  @allowed_extensions ~w(.jpg .jpeg .png .webp)

  def consume(socket, upload_name, folder) do
    Phoenix.LiveView.consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
      {:ok, store(path, entry, folder)}
    end)
  end

  defp store(path, entry, folder) do
    extension =
      entry.client_name
      |> Path.extname()
      |> String.downcase()
      |> valid_extension()

    filename = "#{System.system_time(:millisecond)}-#{random_id()}#{extension}"
    relative_path = Path.join(["uploads", folder, filename])
    destination = Path.join([:code.priv_dir(:smart_kiosk_web), "static", relative_path])

    destination
    |> Path.dirname()
    |> File.mkdir_p!()

    File.cp!(path, destination)

    "/" <> relative_path
  end

  defp valid_extension(extension) when extension in @allowed_extensions, do: extension
  defp valid_extension(_extension), do: ".jpg"

  defp random_id do
    8
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
