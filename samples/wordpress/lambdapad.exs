import Lambdapad

blog do
  pages "index" do
    set from: "pages/hello.md"
    set template: "twentytwentyone/single.php"
    set format: :wordpress
    set uri: "/"
    set var_name: "page"
  end
end
