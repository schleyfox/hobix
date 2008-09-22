<?php
/**
 * This file should be placed in the htdocs of your actual blog repo
 */
if($_POST["payload"]) {
  #run git pull
  system("git pull origin master:master");
  echo "Thank you, come again!";
} else {
  echo "Sorry, you don't come bearing gifts.\n\n";
}
?>

