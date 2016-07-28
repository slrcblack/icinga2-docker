#!/usr/bin/php
<?php
/*
Niles Ingalls 2014 ENA

// report on 

update Jan 8 2015: report on community_id instead of groupid.

here's the view we need.
http://cb01.nsvltn.ena.net:8092/websafe/_design/group/_view/by_community

*/

@list(,$day, $critical) = $argv;

if(isset($day) && $day >= 1) {

	$dbh = new PDO("mysql:host=mysql10.corp.ena.net;dbname=enareporting", 'cfreports', 'cfreports');
	$excludes = array('13098', '20599', '20604', '20605', '20606', '2169', '23619', '27852', '4845', '7583', '8806', '8807', '9109', '7929', '9440'); // excluded communities
//	$dbh->exec("SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED"); <-- kills the query for some reason.
	foreach($dbh->query("select gid, sum(row_count) as total from enareporting.daily_aggregates_counts where logdate >= NOW() - INTERVAL $day DAY group by gid having total > 0 && gid > 0;") as $row) {
		$groups[] = 'group_' . $row['gid'];
	}

	$cb = new Couchbase("cb01.nsvltn.ena.net:8091", "", "", "websafe");
	$cb->setOption(COUCHBASE_OPT_IGNOREFLAGS,true);
	$cb_communities = ($cb->view("group", "by_community"));
	$cb_communities = $cb_communities['rows'];

	foreach($cb_communities AS $community_view) {
		$communities[$community_view['key']][] = $community_view['id'];
	}

	foreach($communities AS $community_id => $community_groups) {
		if(!in_array($community_id, $excludes)) {
			foreach($community_groups AS $groups_eval) {
				if(in_array($groups_eval, $groups)) $found[] = $community_id;
			}
			if(!isset($found) || !in_array($community_id, $found)) {
				$lastdate = lastdate($communities[$community_id]);
				$name = json_decode($cb->Get('community_' . $community_id));
				$community_count[] = true;
				@$msg .= $community_id .'_' . $name->name .'_'. $lastdate . ' ';

			}
		}
	}

	if(isset($msg)) {
			$day = "$day days";
		if(isset($critical) && $critical > 0) {
			printf('CRITICAL -no reporting data- %s - %s|policy_count=%d', $day, $msg, count($community_count));
			exit(2);
		} else { // warning
			printf('WARNING -no reporting data- %s - %s|policy_count=%d', $day, $msg, count($community_count));
			exit(1);
		}
	} else { // ok
		echo 'OK -reporting data for all policies|policy_count=0'; 
		exit(0);
	}

} else {
	echo 'UNKNOWN: no data given';
	exit(3);
}

function lastdate($community) {
	foreach($community AS $comkey => $comid) {
		if($comkey == 0) {
			$gidor = 'gid=' . substr($community[0], 6);
		} else {
			$gidor .= ' || gid=' . substr($comid, 6);
		}
	}
	$stmt = $GLOBALS['dbh']->query("select max(logdate) AS recent from daily_aggregates_counts where ($gidor) && row_count > 0");
	$result = $stmt->fetch(PDO::FETCH_ASSOC);
	if(is_null($result['recent'])) {
		$stmt = $GLOBALS['dbh']->query("select max(logyearweek) AS recent from weekly_aggregates_counts where ($gidor) && row_count > 0");
		$result = $stmt->fetch(PDO::FETCH_ASSOC);
		if(is_null($result['recent'])) {
			$stmt = $GLOBALS['dbh']->query("select max(logyearmonth) AS recent from monthly_aggregates_counts where ($gidor) && row_count > 0");
			$result = $stmt->fetch(PDO::FETCH_ASSOC);
			if(is_null($result['recent'])) {
				$stmt = $GLOBALS['dbh']->query("select max(logyear) AS recent from yearly_aggregates_counts where ($gidor) && row_count > 0");
				$result = $stmt->fetch(PDO::FETCH_ASSOC);
				if(is_null($result['recent'])) {
					return 'NEVER';
				} else {
					return 'YEAR_' . $result['recent'];
				}
			} else {
				return 'MONTH_' . $result['recent'];
			}
		} else {
			return 'WEEK_' . $result['recent'];
		}
	} else {
		return 'DAY_' . $result['recent'];
	}

}
?>
