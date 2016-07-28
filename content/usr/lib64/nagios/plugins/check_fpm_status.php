#!/usr/bin/php
<?php
/*
why do we need this script in addition to PHP-FPM Processes?
Because this takes into account the number of total processes in addition to active ones.
*/

if(count($argv) == 5) {
        list(,$server, $port, $warn, $critical) = $argv;
} else {
        echo "UNKNOWN: incorrect number of arguments given\n";
        exit(3);
}

$starttime = microtime_float();
//$warn = 80;
//$critical = 90;

//$handle = fopen("http://lapp01-mar.marion.in.ena.net:8090/fpm-status.php?json", "rb");
$handle = fopen("http://$server:$port/fpm-status.php?json", "rb");
$contents = stream_get_contents($handle);
fclose($handle);

if(is_object(json_decode($contents))) {

	$response = json_decode($contents);

	$perc = ceil( ( $response->{"active processes"} / $response->{"total processes"} ) * 100 );
	$speed = ((microtime_float() - $starttime) * 1000);
	if($perc >= $critical) {

		printf("CRITICAL: active proesses at %d|activepercentage=%sspeed=%sms", $perc, "$perc%", $speed);
		exit(2);

	} elseif($perc >= $warn) {

		printf("WARN: active processes at %d|activepercentage=%sspeed=%sms", $perc, "$perc%", $speed);
		exit(1);

	} else {

		printf("OK: active processes at %d|activepercentage=%sspeed=%sms", $perc, "$perc%", $speed);
		exit(0);

	}

} else { 

	printf("UNKNOWN: data not received from $server:$port");
	exit(3);

}

function microtime_float()
{
        list($usec, $sec) = explode(" ", microtime());
        return ((float)$usec + (float)$sec);
}


/*

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

*/
?>
