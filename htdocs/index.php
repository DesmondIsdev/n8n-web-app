<!doctype html>
<html>
    <head>
    	<style>
    		body{
    			
			}
    	</style>
    </head>
  <body>
    <h2>Commande</h2>
    <form action="insert_order.php" method="POST">
      <input name="name" placeholder="Nom complet" required><br>
      <input name="email" type="email" placeholder="Email" required><br>
      <input name="product" placeholder="Produit/Service" required><br>
      <input name="phone" placeholder="Téléphone"><br>
      <textarea name="comment" placeholder="Commentaires / exigences"></textarea><br>
      <button type="submit">Commander</button>
    </form>
  </body>
</html>
