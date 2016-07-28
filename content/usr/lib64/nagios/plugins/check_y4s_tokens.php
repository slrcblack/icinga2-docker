#!/usr/bin/php
<?php
/*
Niles Ingalls ENA 2014

*/

$cb = new Couchbase("cb01.nsvltn.ena.net:8091", "", "", "websafe"); 
$cb->setOption(COUCHBASE_OPT_IGNOREFLAGS,true);

$y4s_tokens = $cb->view("policy", "by_y4s");

foreach($y4s_tokens['rows'] AS $token) {

	if(!verify_y4s($token['value'])) {
		$policy = json_decode($cb->get($token['id']));
		$bad_token[] = "$policy->doctype $policy->name $policy->y4stoken";
	}

}

if($y4s_tokens['total_rows'] == 0) {

	echo 'WARNING: no tokens defined in the couchbase view';
	exit(1);

} elseif(isset($bad_token)) { // critical

	 echo 'CRITICAL: ' . implode(' - ', $bad_token) . ' | quantity=' . count($bad_token);
	exit(2);

} else { // ok

	echo 'OK: no errors found | quantity=0';
	exit(0);
}


function verify_y4s($token) {
        $handle = curl_init();
        $url = 'https://www.youtube.com';
        $options = array(
        CURLOPT_URL => $url,
        CURLOPT_HTTPHEADER => array(
	'User-Agent: Mozilla/5.0 (Windows NT 5.1; rv:31.0) Gecko/20100101 Firefox/31.0',
        'X-YouTube-Edu-Filter:' . $token),
        CURLOPT_HEADER => TRUE,
        CURLOPT_RETURNTRANSFER => TRUE,
        CURLOPT_TIMEOUT => 4,
        CURLOPT_SSL_VERIFYHOST => 0,
        CURLOPT_SSL_VERIFYPEER => false);
        curl_setopt_array($handle, $options);
        $verify = curl_exec($handle);
        curl_close($handle);

/* If the token is not valid, youtube sends you to https://www.youtube.com */

if(!strpos($verify, 'Location: https://www.youtube.com')) return TRUE;
}

?>
