#!/usr/bin/php
<?php
/*
Niles Ingalls 2014 ENA
This script will check policy category selections, url overrides and clientid's.
Icinga/Nagios has no patience for long running scripts, so running this script the first
time (per argument) will "rerun" the script in the background and sent an unknown error back to Icinga/Nagios.
Set Icinga/Nagios to re-check 20-30 minutes later, and the script will offer the output of the prior-run background process.

Sep 24th - 2014 -> Add the ability to run the SQL corrections from the check.
Sep 25th - 2014 -> added a SQL dump of any modified policy
Dec 5th - 2014 -> send back OK instead of UNKNOWN, and lower the freqency of the checks.
*/

@list(,$request, $rerun) = $argv;

$sql = array();
$mysql_user = 'ao';
$mysql_pass = 'PrettyPinkPeople';
$fix = true;
$fixnotify = 'ningalls@ena.com,cboone@ena.com';
$filetime = 3600;

if(empty($rerun)) {
	/* stage 2 - send back the previously collected data */
	if(file_exists("/tmp/nrpe/$request") && filemtime("/tmp/nrpe/$request") > (time() - $filetime)) {
	        $handle = fopen("/tmp/nrpe/$request", "r");
		$issues = json_decode(fread($handle, filesize("/tmp/nrpe/$request")));
		fclose($handle);
		if(isset($issues) && count($issues) > '0') {
		        printf('WARNING: ' . implode(' - ', $issues) . " for details - reference /tmp/nrpe/$request.sql | quantity=" . count($issues));
		        exit(1);
		} else {
		        printf('OK: no errors found | quantity=0');
		        exit(0);
		}
	/* before we rerun our script with purpose, make sure it's not already running */
	} elseif(is_file("/tmp/nrpe/$request.pid")) {
		$handle = fopen("/tmp/nrpe/$request.pid", "r");
		$pid = fread($handle, filesize("/tmp/nrpe/$request.pid"));
		fclose($handle);
		exec("ps -p $pid", $ret, $exit);
		if(!$exit) {
			printf('OK: come back later - this script is still processing');
			exit(0);
		} else {
			/* stage 1 - rerun our script as a background process */
			shell_exec(sprintf('%s > /dev/null 2>&1 &', $_SERVER['PHP_SELF'] . " $request rerun"));
	                echo 'OK: processing - come back soon';
	                exit(0);
		}
	} else {

		/* stage 1 - rerun our script as a background process */		
		shell_exec(sprintf('%s > /dev/null 2>&1 &', $_SERVER['PHP_SELF'] . " $request rerun"));
		echo 'OK: processing - come back soon';	
		exit(0);
	}
}

/* drop a pid */

$handle = fopen("/tmp/nrpe/$request.pid", "w");
fwrite($handle, getmypid());
fclose($handle);

$cb = new Couchbase("cb01.nsvltn.ena.net:8091", "", "", "websafe"); 
$cb->setOption(COUCHBASE_OPT_IGNOREFLAGS,true);

/* let's grab a filter document. */

$filters = $cb->view("filter", "by_name"); 
foreach($filters['rows'] AS $filter) if($filter['key'] == $request) $my_filter = json_decode($cb->get($filter['id']));

if(!isset($my_filter)) {
	printf('UNKNOWN: no filter document found');
	exit(3);
}

$issues = array(); /* we start with no issues, and let's hope it stays that way */

/* grab any communities associated to our filter locations. */

foreach($my_filter->location AS $loc) {
	$communities = $cb->view("checks", "policy_by_location", array('key' => $loc));
	foreach($communities['rows'] AS $community) $policies[]['id'] = $community['id'];
}

if(!isset($policies)) die("no policies associated to this nsw\n");

foreach($policies AS $policy) {

	$policyid = trim(substr($policy['id'], 7));

	/* obtain all overrides defined in couchbase for this particular policy. */
	$category = $cb->view("list", "by_policy", array('key' => $policyid, 'full_set' => TRUE));

	if(count($category['rows']) > '0') {
		foreach($category['rows'] AS $list) {
			$get_list = json_decode($cb->get($list['id']));
			$override[$policyid][$get_list->state][$get_list->type][$get_list->id] = $get_list->value; /* use get_list->id as a key, so we can reference it later. */
		}
	} else { /* this policy has no overrides. */
		$override[$policyid] = array();
	}
		
	$trans = array('U' => 'url', 'R' => 'regexp', 'K' => 'keyword', 'E' => 'extension'); /* array_key = netsweeper , array_value = couchbase */

	/* Grab some couchbase documents  */

	/* Categories */
  $get_policy = json_decode($cb->get($policy['id']));
  $groupid = $get_policy->group;

	try {
		$dbh = new PDO("mysql:host=$my_filter->name;dbname=NSDConfig", 'ao', 'PrettyPinkPeople');
	} catch(PDOException $ex) {
		$issues[] = "Unable to connect to $my_filter->name via MYSQL";
		$handle = fopen("/tmp/nrpe/$my_filter->name", "w");
		fwrite($handle, json_encode($issues));
		fclose($handle);
		/* dump the pid file */
		unlink("/tmp/nrpe/$request.pid");
		die();
	}
	foreach($dbh->query("SELECT timepolicy.cat, tpid FROM groups, timepolicy WHERE groups.name = '$get_policy->group' && groups.groupid = timepolicy.groupid") as $row) {
		foreach($get_policy->category AS $ccat) {
			if(!isset($cat_external[$ccat])) {
				$get_category = json_decode($cb->get('category_' . $ccat));
				$cat_external[$ccat] = $get_category->external; // "external" represents the Native netsweeper category id's
			}
			$category_compare[] = $cat_external[$ccat];	
		}
		if(!empty($row['cat'])) {
			$ncat = explode(',', $row['cat']);
		} else {
			$ncat = array();
		}
		if(isset($category_compare)) {
			$compare_cat_cb = array_diff($category_compare, $ncat);
			if(count($compare_cat_cb) > '0') {
				$issues[] = "CATEGORIES_MISSING: not present on netsweeper: $my_filter->name timepolicy.id " . $row['tpid'] . ' ' . implode(',', $compare_cat_cb);
				$sql[] = sprintf("UPDATE timepolicy SET cat = '%s' WHERE tpid = '%d';", implode(',', $category_compare), $row['tpid']);
			}
			$compare_cat_nsw = array_diff($ncat, $category_compare);
			if(count($compare_cat_nsw) > '0') {
				$issues[] = "CATEGORIES_MISSING: not present in cb document policy_$get_policy->id " . ' ' . implode(',', $compare_cat_nsw);
				$sql[] = sprintf("UPDATE timepolicy SET cat = '%s' WHERE tpid = '%d';", implode(',', $category_compare), $row['tpid']);
			}
		}
		unset($category_compare, $cat);
	}

	/* Clients -- need to determine this via group */

	$clients = $cb->view("client", "by_group", array('key' => $get_policy->group));
	if(!isset($compare_client_cb)) $compare_client_cb = array();
	if(!isset($compare_client_nsw)) $compare_client_nsw = array();

	foreach($clients['rows'] AS $client) {
		$get_client = json_decode($cb->get($client['id']));
		$compare_client_cb[$client['id']] = "$get_client->ip,$get_client->subnet";
	}

	foreach($dbh->query("SELECT clientid, CONCAT(ip,',',subnet) AS client
			FROM clientid
			LEFT JOIN groups ON groups.groupid = clientid.groupid
			WHERE groups.name = '$get_policy->group'") as $row) {

		$compare_client_nsw[$row['clientid']] = $row['client'];
	}

	if($return = cb_client_compare($compare_client_cb, $compare_client_nsw, $get_policy->group, $my_filter->name))	$issues = array_merge($issues, $return);

	/* Overrides */
	if(!isset($nsw_override)) $nsw_override = array();

	foreach($dbh->query("SELECT urllist.urlid, urllist.type, urllist.listAllow, urllist.url
			FROM urllist 
			LEFT JOIN timepolicy ON urllist.tpid = timepolicy.tpid
			LEFT JOIN groups ON groups.groupid = timepolicy.groupid
			WHERE groups.name = '$get_policy->group'") as $row) {

		if($row['listAllow'] == 1) {
			$nsw_override[$policyid]['allow'][$trans[$row['type']]][$row['urlid']] = $row['url'];
		} else {
			$nsw_override[$policyid]['deny'][$trans[$row['type']]][$row['urlid']] = $row['url'];
		}
	}

	if($return = cb_nsw_compare($override, $nsw_override, $policyid, $groupid, $my_filter->name, 'allow', 'url'))	$issues = array_merge($issues, $return);
	if($return = cb_nsw_compare($override, $nsw_override, $policyid, $groupid, $my_filter->name, 'allow', 'regexp'))	$issues = array_merge($issues, $return);
	if($return = cb_nsw_compare($override, $nsw_override, $policyid, $groupid, $my_filter->name, 'allow', 'keyword')) $issues = array_merge($issues, $return);
	if($return = cb_nsw_compare($override, $nsw_override, $policyid, $groupid, $my_filter->name, 'deny', 'url'))	$issues = array_merge($issues, $return);
	if($return = cb_nsw_compare($override, $nsw_override, $policyid, $groupid, $my_filter->name, 'deny', 'regexp'))	$issues = array_merge($issues, $return);
	if($return = cb_nsw_compare($override, $nsw_override, $policyid, $groupid, $my_filter->name, 'deny', 'keyword'))	$issues = array_merge($issues, $return);

	if(isset($override)) unset($override);
}

/* drop our results into a tmp file for later use */

$handle = fopen("/tmp/nrpe/$my_filter->name", "w");
fwrite($handle, json_encode($issues));
fclose($handle);

/* dump the pid file */

unlink("/tmp/nrpe/$request.pid");

/* sql suggestions to correct issues */

foreach($sql AS $statement) $statements[] = $statement;

if(isset($statements) && isset($fix)) {

/* back everything up */

if(!is_dir('/tmp/nrpe/backups')) mkdir('/tmp/nrpe/backups');

exec(sprintf("/usr/bin/mysqldump -h%s -u%s -p%s NSDConfig > /tmp/nrpe/backups/%s-%s", $my_filter->name, $mysql_user, $mysql_pass, $my_filter->name, date("Y-m-d-h-i")));

	try {
		$dbh = new PDO("mysql:host=$my_filter->name;dbname=NSDConfig", $mysql_user, $mysql_pass);
		foreach($statements AS $statement) {

			$stmt = $dbh->prepare($statement);
			$stmt->execute();
		}
		$dbh = null;

		if(isset($fixnotify)) { // tell someone about it.

			$subject = sprintf('Filter corrections for %s - %s', $my_filter->name, date("Y-m-d: H:i:s"));
			$message = "SQL corrections:\n";
			$message .= implode("\n", $statements);

			if(strpos($fixnotify, ',') !== false) {

				$sendnotify = explode(',', $fixnotify);

			} else {

				$sendnotify[] = $fixnotify;

			}

			foreach($sendnotify AS $notify) {

				if(filter_var($notify, FILTER_VALIDATE_EMAIL)) {

					mail($notify, $subject, $message, "From: noreply@ena.com\r\nReply-To: noreply@ena.com\r\nX-Mailer: PHP/" . phpversion());
				}

			}
		}

	} catch (PDOException $e) {

		$handle = fopen("/tmp/nrpe/$my_filter->name.sql", "w");
	        fwrite($handle, implode("\n", $statements));
	        fclose($handle);
		if(isset($fixnotify)) { // tell someone there's an issue.

		}
	}

} elseif(isset($statements)) {

	$handle = fopen("/tmp/nrpe/$my_filter->name.sql", "w");
	fwrite($handle, implode("\n", $statements));
	fclose($handle);
} elseif(is_file("/tmp/nrpe/$my_filter->name.sql")) {
	unlink("/tmp/nrpe/$my_filter->name.sql");
}

function cb_client_compare($cb_client, $nsw_client, $groupid, $nsw) {

	if(isset($cb_client[$groupid])) {
		if(isset($nsw_client[$groupid])) {
			$compare_cb = array_diff($cb_client[$groupid], $nsw_client[$groupid]);
			if(count($compare_cb) > '0') {
				foreach($compare_cb AS $missing_key => $missing_nsw) {
					$return[] = "CLIENT_MISSING: on $nsw $missing_key $missing_nsw";
					list($ip, $subnet) = explode(',', $missing_nsw);
					$GLOBALS['sql'][] = sprintf("INSERT INTO clientid (groupid, ip, subnet, username, lastchange) SELECT groupid, '%s' AS ip, '%s' AS subnet, name, NOW() FROM groups WHERE groups.name = '%d';", $ip, $subnet, $groupid);
				}
			}
			$compare_nsw = array_diff($nsw_client[$groupid], $cb_client[$groupid]);
			if(count($compare_nsw) > '0') {
				foreach($compare_nsw AS $missing_key => $missing_nsw) {
					$return[] = "CLIENT_MISSING: on couchbase clientid.clientid ($nsw) $missing_key $missing_nsw";
					$GLOBALS['sql'][] = sprintf("DELETE FROM clientid  WHERE username = '%d' AND ip = '%s' AND subnet = '%s';", $groupid, $ip, $subnet);
				}
			}
		} else { // clients don't exist on nsw
			foreach($compare_cb AS $client_key => $client_insert) {
				$return[] = "CLIENT_MISSING: on $nsw $client_key $client_insert";
				$GLOBALS['sql'][] = sprintf("INSERT INTO clientid (groupid, ip, subnet, username, lastchange) SELECT groupid, '%s' AS ip, '%s' AS subnet, name, NOW() FROM groups WHERE groups.name = '%d';", $ip, $subnet, $groupid);
			}
		}
	} elseif(isset($compare_nsw[$groupid])) { /* clients don't exist in cb */
		foreach($compare_nsw AS $nsw_key => $nsw_insert) {
			$return[] = "CLIENT_MISSING: on couchbase clientid.clientid ($nsw) $nsw_key $nsw_insert";
			$GLOBALS['sql'][] = sprintf("DELETE FROM clientid  WHERE username = '%d' AND ip = '%s' AND subnet = '%s';", $groupid, $ip, $subnet);
		}
	}

	if(isset($return)) return $return;
}

function cb_nsw_compare($override, $nsw_override, $policyid, $groupid, $nsw, $list, $type) {
	$trans = array_flip($GLOBALS['trans']);
	$transtype = array('allow' => 1, 'deny' => 2);
	if(isset($override[$policyid][$list][$type])) {
		if(isset($nsw_override[$policyid][$list][$type])) {
			$compare_cb = array_diff($override[$policyid][$list][$type], $nsw_override[$policyid][$list][$type]);
			if(count($compare_cb) > '0') {
				foreach($compare_cb AS $missing_key => $missing_nsw) {
					$return[] = "OVERRIDE_MISSING: on $nsw list_$missing_key $missing_nsw"; // OOPS!
					$GLOBALS['sql'][] = sprintf("INSERT INTO urllist(url, type, listAllow, tpid) SELECT '%s' AS url, '%s' AS type, '%s' AS listAllow, tpid FROM timepolicy LEFT JOIN groups ON groups.groupid = timepolicy.groupid WHERE groups.name = '%d';", mysql_escape_string($missing_nsw), $trans[$type], $transtype[$list], $groupid);
				}
			}
			$compare_nsw = array_diff($nsw_override[$policyid][$list][$type], $override[$policyid][$list][$type]);
			if(count($compare_nsw) > '0') {
				foreach($compare_nsw AS $missing_key => $missing_cb) {
					$return[] = "OVERRIDE_MISSING: on couchbase urllist.urlid ($nsw) $missing_key $missing_cb";
					$GLOBALS['sql'][] = sprintf("DELETE FROM urllist WHERE urlid = '%d';", $missing_key);
				}
                        }      
		} else { /* overrides don't exist on nsw */
			foreach($override[$policyid][$list][$type] AS $override_key => $override_insert) {
				$return[] = "OVERRIDE_MISSING: on $nsw list_$override_key $override_insert";
				$GLOBALS['sql'][] = sprintf("INSERT INTO urllist(url, type, listAllow, tpid) SELECT '%s' AS url, '%s' AS type, '%s' AS listAllow, tpid FROM timepolicy LEFT JOIN groups ON groups.groupid = timepolicy.groupid WHERE groups.name = '%d';", mysql_escape_string($override_insert), $trans[$type], $transtype[$list], $groupid);
			}
		}
	} elseif(isset($nsw_override[$policyid][$list][$type])) { // overrides don't exist in cb
		foreach($nsw_override[$policyid][$list][$type] AS $nsw_key => $nsw_insert) {
			$return[] = "OVERRIDE_MISSING: on couchbase urllist.urlid ($nsw) $nsw_key $nsw_insert";
			$GLOBALS['sql'][] = sprintf("DELETE FROM urllist WHERE urlid = '%d';", $nsw_key);
		}
	}
	if(isset($return)) return $return;
}
?>
