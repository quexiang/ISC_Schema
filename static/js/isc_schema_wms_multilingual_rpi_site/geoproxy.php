<?php
$url=$_GET["url"];
$res = file_get_contents($url);
echo $res;
?>