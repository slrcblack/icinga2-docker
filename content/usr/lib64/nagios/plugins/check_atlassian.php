#!/usr/bin/php
<?php
/* Niles Ingalls 2014 ningalls@ena.com
 * Icinga/Nagios basic health checks for Atlassian applications.
 *
 * NOTE: be sure the crowd application is configured to allow
 * access from your icinga ip address.
 * also, crowd is a prerequisite for any other Atlassian product,
 * so run that check regardless of request BEFORE the request.
 * if crowd isn't responding, there's no reason to continue.
 * example usage:
 * ./check_atlassian.php jira jira.ena.com 8080 1750 2250
 * ./check_atlassian.php stash stash.corp.ena.net 7990 1750 2250
 * ./check_atlassian.php bamboo bamboo.corp.ena.net 8085 1750 2250
 * ./check_atlassian.php confluence wiki.ena.com 8080 1750 2250
 * ./check_atlassian.php crowd  1750 2250
 */

if(!isset($argv[1])) die ("Nothing to do. Please pass me arguments\n");

$atl = new Atlassian();

$atl->crowdvars = array('host' 			=>	'crowd.corp.ena.net',
			'port'			=>	'8095',
			'cuser'			=>	'crowd',
			'cpass'			=>	'en@en@1995',
			'application'		=>	'crowd_check:crowd_check1995');

$starttime = $atl->microtime_float(); // begin speed calculation

switch($argv[1]) {

	case 'crowd':

		if($atl->crowd()) {

			$speed = (($atl->microtime_float() - $starttime) * 1000); // end speed calculation

			if($speed < $argv[2]) { // OK

				printf('NORMAL: Crowd Authorization %1$fms | ms=%1$f;%2$d;%3$d', $speed, $argv[2], $argv[3]);
				exit(0);

			} elseif ($speed < $argv[3]) { // WARNING

				printf('WARNING: Crowd Authorization %1$fms | ms=%1$f;%2$d;%3$d', $speed, $argv[2], $argv[3]);
				exit(1);

			} elseif ($speed >= $argv[3]) {

				printf('CRITICAL: Crowd Authorization %1$fms | ms=%1$f;%2$d;%3$d', $speed, $argv[2], $argv[3]);
				exit(2);

			} else {

				printf('Unknown: response not recognized');
				exit(3);

			}
				
		} else {
			echo 'CRITICAL: Crowd cannot authenticate';
			exit(2);
		}
		break;

	case 'bamboo':
	case 'confluence':
	case 'jira':
        case 'stash':

                if($atl->$argv[1]($argv[2], $argv[3], $atl->crowdvars['cuser'] . ':' . $atl->crowdvars['cpass'])) { 

                        $speed = (($atl->microtime_float() - $starttime) * 1000); // end speed calculation

                        if($speed < $argv[4]) { // OK

                                printf('NORMAL: Atlassian checks: (%s) %2$fms | ms=%2$f;%3$d;%4$d', ucfirst($argv[1]), $speed, $argv[4], $argv[5]);
                                exit(0);

                        } elseif ($speed < $argv[5]) { // WARNING

                                printf('WARNING: Atlassian checks: (%s) %2$fms | ms=%2$f;%3$d;%4$d', ucfirst($argv[1]), $speed, $argv[4], $argv[5]);
                                exit(1);

                        } elseif ($speed >= $argv[5]) {

                                printf('CRITICAL: Atlassian checks (%s) %2$fms | ms=%2$f;%3$d;%4$d', ucfirst($argv[1]), $speed, $argv[4], $argv[5]);
                                exit(2);

                        } else {

                                printf('Unknown: response not recognized');
                                exit(3);

                        }

                } else {

                        if($atl->crowd()) {

				printf('CRITICAL: %s cannot authenticate', ucfirst($argv[1]));
                                exit(2);

                        } else {

				printf('CRITICAL: %s: Crowd related failure', ucfirst($argv[1]));
                                exit(2);

                        }

                }

        break;

	default:
		printf('Unknown: response not recognized');
		exit(3);

}

class Atlassian {

        function bamboo($host, $port, $authentication) {

                /*
                        The request below returns a list of projects
                */

                if(!isset($bamboo_handle)) $bamboo_handle = curl_init();

                $options = array(
                CURLOPT_USERPWD => $authentication,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_CONNECTTIMEOUT => 0,
                CURLOPT_CONNECTTIMEOUT => 30,
                CURLOPT_HTTPHEADER => array('Content-Type: application/json','Accept: application/json'),
                CURLOPT_URL => $host . ':' . $port . '/rest/api/latest/plan');
                curl_setopt_array($bamboo_handle, $options);
                $reply = curl_exec($bamboo_handle);
                curl_close($bamboo_handle);
                $json = json_decode($reply);

                if(isset($json->plans)) return TRUE;

        }

	function confluence($host, $port, $authentication, $space = 'CTAC') {

		/*
			The request below returns data from this page: http://wiki.ena.com/spacedirectory/view.action
			You can use any expected object (example: CTAC) for verification.
		*/
		if(!isset($confluence_handle)) $confluence_handle = curl_init();

                $options = array(
                CURLOPT_USERPWD => $authentication,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_CONNECTTIMEOUT => 0,
                CURLOPT_CONNECTTIMEOUT => 30,
                CURLOPT_HTTPHEADER => array('Content-Type: application/json','Accept: application/json'),
                CURLOPT_URL => $host . ':' . $port . '/rest/prototype/1/space');
                curl_setopt_array($confluence_handle, $options);
                $reply = curl_exec($confluence_handle);
                curl_close($confluence_handle);
                $json = json_decode($reply);

		if(isset($json->space)) foreach($json->space AS $response) if($response->name == $space) return TRUE;

	}

	function crowd() {

                if(!isset($crowd_handle)) $crowd_handle = curl_init();

                $options = array(
		CURLOPT_USERPWD => $this->crowdvars['application'],
		CURLOPT_RETURNTRANSFER => true,
                CURLOPT_POSTFIELDS => '{"value": "' . $this->crowdvars['cpass'] . '"}',
                CURLOPT_HTTPHEADER => array('Content-Type: application/json','Accept: application/json'),
                CURLOPT_URL => $this->crowdvars['host'] . ':' . $this->crowdvars['port'] . '/crowd/rest/usermanagement/1/authentication?username=' . $this->crowdvars['cuser']);
		curl_setopt_array($crowd_handle, $options);
                $reply = curl_exec($crowd_handle);
                curl_close($crowd_handle);
                $json = json_decode($reply);

                if(isset($json->active) && ($json->active == 1)) return TRUE;
        }

        function jira($host, $port, $authentication) {

                /*
                        The request below returns the dashboard
                */
                if(!isset($jira_handle)) $jira_handle = curl_init();

                $options = array(
                CURLOPT_USERPWD => $authentication,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_CONNECTTIMEOUT => 0,
                CURLOPT_CONNECTTIMEOUT => 30,
                CURLOPT_HTTPHEADER => array('Content-Type: application/json','Accept: application/json'),
                CURLOPT_URL => $host . ':' . $port . '/rest/api/2/dashboard');
                curl_setopt_array($jira_handle, $options);
                $reply = curl_exec($jira_handle);
                curl_close($jira_handle);
                $json = json_decode($reply);

		if(isset($json->dashboards) && is_array($json->dashboards)) return TRUE;

        }

        function stash($host, $port, $authentication) {

                /*
                        The request below returns a list of projects
                */
                if(!isset($stash_handle)) $stash_handle = curl_init();

                $options = array(
                CURLOPT_USERPWD => $authentication,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_CONNECTTIMEOUT => 0,
                CURLOPT_CONNECTTIMEOUT => 30,
                CURLOPT_HTTPHEADER => array('Content-Type: application/json','Accept: application/json'),
                CURLOPT_URL => $host . ':' . $port . '/rest/api/1.0/projects');
                curl_setopt_array($stash_handle, $options);
                $reply = curl_exec($stash_handle);
                curl_close($stash_handle);
                $json = json_decode($reply);

                if(isset($json->size)) return TRUE;

        }

        function microtime_float()
        {
                list($usec, $sec) = explode(" ", microtime());
                return ((float)$usec + (float)$sec);
        }

}
