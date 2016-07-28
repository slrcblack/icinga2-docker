#!/usr/bin/php
<?php
/*
Niles Ingalls 2014 ENA

find and mention any duplicate url entries
*/

@list(,$nsw) = $argv;

$dbh = new PDO("mysql:host=$nsw;dbname=NSDConfig", 'ao', 'PrettyPinkPeople');
$dupes = array();

foreach($dbh->query("SELECT tpid, url, type, listAllow, (SELECT description FROM groups a LEFT JOIN timepolicy c ON c.groupid = a.groupid WHERE c.tpid = b.tpid) AS policy FROM urllist b GROUP BY policy, tpid, url, type, listAllow HAVING COUNT(*) > 1") as $row) {

	$dupes[] = 'Policy:' . $row['policy'] . ' tpid:' . $row['tpid'] . ' url:' . $row['url'] . ' type:' . $row['type'] . ' listAllow:' . $row['listAllow'];

}

if(count($dupes) > 0) {
	printf('WARNING - ' . implode(" ", $dupes));
	exit(1);
} else {
	printf('OK - no dupes');
	exit(0);
}
?>
