#!/usr/bin/php
<?php
	/*
		Niles Ingalls @ ENA 2013
		Nagios checks for WebSafe via API

		$USER1$/check_websafe.php $HOSTADDRESS$ $ARG1$ $ARG2$ $ARG3$ $ARG4$
		speed check: 		check_websafe.php 172.27.18.232 speed 300 600 1
		authorization check:	check_websafe.php 172.27.18.232 authorization 300 600 1
	*/

if(!isset($argv[1])) die ("Nothing to do. Please pass me arguments\n"); // be more description. perhaps, provide all possible arguments.

$ws = new WebSafe();
$ws->ws_host = $argv[1]; // define hostname 
$ws_starttime = $ws->microtime_float(); // begin speed calculation

switch($argv[2]) {

	case 'authorization':

		/*
			Authorization check per John Smith (e-mail from October 21st, 2013)
			Use: check_websafe.php {HostAddress} authorization {reuse-session time}
			if you want performance data on result speed, add two more arguments for {min} {max}
		*/
		$authorized = $ws->SignIn($argv[5]);

		if(!$authorized->signedIn) {

			printf('CRITICAL: %s cannot sign in', $ws->ws_username);
	                exit(2);

		}

		$uri = '/isauthorized';
		$json = json_encode(array('sessionId' => $authorized->sessionId,
						'product' => 'ENA.API.WebSafe.Policy',
						'feature' => 'CreateCategory'));

		$send = $ws->Post($uri, $json);

                if ($send->isAuthorized) {

                        $speed = (($ws->microtime_float() - $ws_starttime) * 1000); // end speed calculation

			if (isset($argv[3]) && isset($argv[4])) {

	                        if ($speed < $argv[3]) { // OK

	                                printf('NORMAL: isAuthorized %1$fms | ms=%1$f;%2$d;%3$d', $speed, $argv[3], $argv[4]);
	                                exit(0);

	                        } elseif ($speed < $argv[4]) { // WARNING

	                                printf('WARNING: isAuthorized %1$fms | ms=%1$f;%2$d;%3$d', $speed, $argv[3], $argv[4]);
	                                exit(1);

	                        } elseif ($speed >= $argv[4]) { // CRITICAL

	                                printf('CRITICAL: isAuthorized %1$fms | ms=%1$f;%2$d;%3$d', $speed, $argv[3], $argv[4]);
	                                exit(2);

	                        } else {

	                                printf('Unknown: response not recognized');
	                                exit(3);

	                        }

	                } else {

				echo 'NORMAL: isAuthorized';
				exit(0);

			}

		} else {

			printf('CRITICAL: response %s', $send->responseStatus);

		}	

	break;
	case 'signin': /* for testing purposes */
		@$test = $ws->SignIn($argv[3], $argv[4]);
		print_r($test);
		echo "\n";
		$ws->SignOut();
		$speed = $ws->microtime_float() - $ws_starttime; // end speed calculation
		if ($speed < 1) { printf("completed in %f milliseconds\n", ($speed * 1000) ); } else { echo "completed in $speed seconds\n"; }
		
	break;
	case 'speed': 

		/* output speed check for nagios including performance data
			$argv[3] = min time in ms
			$argv[4] = max time in ms
			$atgv[5] = reuse session (in hours)
		*/

		if (!(isset($argv[3]) && isset($argv[4]) && isset($argv[5]))) { echo "usage: check_websafe.php speed {min_time in ms} {max_time in ms} {reuse session in hours}"; exit(3); }

		$login = $ws->SignIn($argv[5]);
		$ws->SignOut();

		if ($login->signedIn) {

			$speed = (($ws->microtime_float() - $ws_starttime) * 1000); // end speed calculation

			if ($speed < $argv[3]) { // OK

				printf('NORMAL: response %1$fms | ms=%1$f;%2$d;%3$d', $speed, $argv[3], $argv[4]);
				exit(0);

			} elseif ($speed < $argv[4]) { // WARNING

				printf('WARNING: response %1$fms | ms=%1$f;%2$d;%3$d', $speed, $argv[3], $argv[4]);
				exit(1);

			} elseif ($speed >= $argv[4]) { // CRITICAL

				printf('CRITICAL: response %1$fms | ms=%1$f;%2$d;%3$d', $speed, $argv[3], $argv[4]);
				exit(2);

			} else {

				printf('Unknown: response not recognized | ms=;%d;%d', $argv[3], $argv[4]);
				exit(3);

			}

		}

	break;

	default:
		echo "Unknown: invalid argument";
		exit(3);

}

class WebSafe {

	var $ws_host;
	var $ws_session_port = '8001';
	var $ws_authorization_port = '8002';
	var $ws_curl_options = array(CURLOPT_HTTPHEADER => array("Content-Type: application/json"));
	var $ws_username = 'enaapimonitor@ena.com';
	var $ws_password = 'ena1995test';
	var $ws_session_extended = TRUE; // if true, will return extended session information (cost is a performance hit)
	var $ws_session_file = '/tmp/check_websafe_session.txt';
	var $ws_sessionId;
	var $ws_signedIn;
	var $ws_policy;

	function time($start) { // calculate and return time (in seconds)

		return $start - $this->microtime_float();

	}

	function microtime_float()
	{
		list($usec, $sec) = explode(" ", microtime());
		return ((float)$usec + (float)$sec);
	}

	function Post($uri, $json) {

                $options = array(CURLOPT_URL => $this->ws_host . ':' . $this->ws_authorization_port . $uri,
                                CURLOPT_POSTFIELDS => $json,
                                CURLOPT_HTTPHEADER => array("Content-Type: application/json"),
				CURLOPT_COOKIE => "ENAAuth=securekey&$this->ws_sessionId; EnaSessionId=$this->ws_sessionId",
                                CURLOPT_RETURNTRANSFER => TRUE);

                $handle = curl_init();
                curl_setopt_array($handle,($options));
                $response = json_decode($result = curl_exec($handle));
                curl_close($handle);

		return $response;

	}

	function SignIn ($reuse_session_length, $session = NULL, $authonly = NULL) {

		$uri = '/signin';

		/*
			http://172.27.18.205:8081/json/metadata?op=SignIn
			Reuse a previous sessionId by defining session in cookie ENAAuth & EnaSessionId

		*/
	
		$json = json_encode(array('username' => $this->ws_username, 'password' => $this->ws_password));	

                $options = array(CURLOPT_URL => $this->ws_host . ':' . $this->ws_session_port . $uri,
                                CURLOPT_POSTFIELDS => $json,
                                CURLOPT_HTTPHEADER => array("Content-Type: application/json"),
                                CURLOPT_RETURNTRANSFER => TRUE);


		if (isset($session)) { /* if session is passed to the script, we use it regardless of $reuse_session_length or $this->ws_session_file */

			$options = $options + array(CURLOPT_COOKIE => "ENAAuth=securekey&$session; EnaSessionId=$session;");

		} elseif (isset($reuse_session_length) && file_exists($this->ws_session_file) && (time()-filemtime($this->ws_session_file) < $reuse_session_length * 3600)) {

			if(is_readable($this->ws_session_file) && filesize($this->ws_session_file) > 0) {

				$handle = fopen($this->ws_session_file, "r");
				$session = fread($handle, filesize($this->ws_session_file));
				fclose($handle);

			} else {

				/* we read an empty or corrupt session file.
				   send back a warn, and delete the file
				*/
				unlink($this->ws_session_file);
				printf('WARNING: cached session file was corrupt or empty');
				exit(1);

			}

                        $uri .= "/sessionId/$session";
			$options = $options + array(CURLOPT_URL => $this->ws_host . ':' . $this->ws_session_port . $uri,
						CURLOPT_COOKIE => "ENAAuth=securekey&$session; EnaSessionId=$session;");

		}

		$handle = curl_init();
		curl_setopt_array($handle,($options + $this->ws_curl_options));
		$response = json_decode($result = curl_exec($handle));
		curl_close($handle);

		if (isset($response) && ($response->{'signedIn'} && !empty($response->{'sessionId'}))) {

		/*	write our session file, for later (re)use	*/

			$handle = fopen($this->ws_session_file, "w");
			fwrite($handle, $response->{'sessionId'});
			fclose($handle);			

			if ($authonly) {

				return $response->{'sessionId'};

			} else {

				$this->ws_sessionId = $response->{'sessionId'};
				$this->ws_signedIn = $response->{'signedIn'};
				return $response;

			}

		} else { /* you got login problems */

			unlink($this->ws_session_file);
			printf('CRITICAL: Login problem: %s', @$response->{'responseStatus'});
                        exit(2);

		}


	}

	function SignOut () {

	/*
		http://172.27.18.205:8081/json/metadata?op=SignOut
		The docs claim that I can sign out via GET or POST,
		but I've only been sucessful using POST.
		via GET, I'm told "ENA Session not found or already signed out."
	*/

		$uri = '/signout';
		$json = json_encode(array('sessionId' => $this->ws_sessionId));

		        $options = array(CURLOPT_URL => $this->ws_host . ':' . $this->ws_session_port . $uri,
		                        CURLOPT_POSTFIELDS => $json,
		                        CURLOPT_RETURNTRANSFER => TRUE);

		$handle = curl_init();
		curl_setopt_array($handle,($options + $this->ws_curl_options));
		$response = curl_exec($handle);
	        curl_close($handle);
	}
}
?>
