#!/usr/bin/php
<?php
/*
Niles Ingalls ENA 2014
The other check (check_rabbitmq_queue.sh) was failing of the messages object did not exist, but that condition didn't necessarily mean failure,
so I threw this one together.
*/

if(count($argv) == 6) {
	list(,$server, $port, $username, $password, $queue) = $argv;
} else {
	echo "UNKNOWN: incorrect number of arguments given\n";
	exit(3);
}

$options = array(CURLOPT_URL => "http://$server:$port/api/queues/%2F/$queue",
		CURLOPT_USERPWD => "$username:$password",
		CURLOPT_HTTPHEADER => array("Content-Type: application/json"),
		CURLOPT_TIMEOUT => 60,
		CURLOPT_RETURNTRANSFER => TRUE);
$handle = curl_init();
curl_setopt_array($handle,($options));
$response = (array) json_decode($result = curl_exec($handle));
curl_close($handle);

if(isset($response['status']) && $response['status'] == 'running') {
	if(!is_object($response['backing_queue_status'])) {
		echo "CRITICAL: backing_queue_status information not available";
		exit(2);
	}elseif(!isset($response['backing_queue_status']->ram_msg_count)) {
		echo "CRITICAL: backing_queue_status->ram_msg_count not available";
		exit(2);
	}elseif($response['backing_queue_status']->ram_msg_count > 0) {
		printf("WARNING: %d failed policy job(s) message in %s queue!|jobs=%d;;;0",$response['backing_queue_status']->ram_msg_count, $queue, $response['backing_queue_status']->ram_msg_count);
		exit(1);
	} else {
		printf("OK: No messages on %s queue.|jobs=0;;;0", $queue);
		exit(0);
	}
} else {
	echo "CRITICAL: rabbitmq not running";
	exit(2);
}
?>
