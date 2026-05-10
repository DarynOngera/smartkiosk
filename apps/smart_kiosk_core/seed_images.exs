alias SmartKioskCore.Repo
alias SmartKioskCore.Schemas.ProductImage

images = [
  {"9c26ea56-403f-4694-a28c-2d72887033d1", "https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=300&q=80"},
  {"24697b2b-053b-4074-b764-801ca5a63c9a", "https://images.unsplash.com/photo-1586484641989-1064883445cd?auto=format&fit=crop&w=300&q=80"},
  {"6965f455-c998-4e79-b17b-5b63d06875e9", "https://images.unsplash.com/photo-1605330369967-17293a52f447?auto=format&fit=crop&w=300&q=80"},
  {"4d745353-aa99-43fd-9618-7b591255a8a2", "https://images.unsplash.com/photo-1550583724-b2692b85b159?auto=format&fit=crop&w=300&q=80"},
  {"bc604e54-0f33-4163-bdae-252d3f80b100", "https://images.unsplash.com/photo-1574366504242-706d860f0312?auto=format&fit=crop&w=300&q=80"}
]

Enum.each(images, fn {product_id, url} ->
  %ProductImage{}
  |> ProductImage.changeset(%{product_id: product_id, url: url, alt_text: "Product Image"})
  |> Repo.insert!()
end)

IO.puts "Seeded 5 product images"
