#!/usr/bin/php
<?php
/*

Niles Ingalls 2014 ENA

	Vars returned from query:
	Database
	Blocked SPID Status
	Blocked Event Info
	Blocking SPID
	Blocking Event Info
	Blocked since

*/

$conn = mssql_connect("mssql01.corp.ena.net:1433", "rainy", "g00ey");
mssql_select_db('Montrose', $conn);

$query = 'SS_DBA_Dashboard.[dbo].[usp_BlockingProcesses]   @BlockingMinutes = 10,@ShowRootOnly=0';

$result = mssql_query($query) or die("fix your sql $sql\n");

if(mssql_num_rows($result) > '0') {
	mssql_close($conn);
	while($row = mssql_fetch_array($result)) {
		if($row['Blocking SPID'] > 0) {
			printf('CRITICAL: DB Blocked (>10 min) SPID: %s STATUS: %s', $row['Blocking SPID'], $row['Blocked SPID Status']);
			exit(2);
		} else {
			mssql_close($conn);
			echo 'NORMAL: no blocking reported';
			exit(0);	
		}		
	}
}

$query = 'SS_DBA_Dashboard.[dbo].[usp_BlockingProcesses]   @BlockingMinutes = 5,@ShowRootOnly=0';
$result = mssql_query($query) or die("fix your sql $sql\n");

if(mssql_num_rows($result) > '0') {
	mssql_close($conn);
        while($row = mssql_fetch_array($result)) {
		if($row['Blocking SPID'] > 0) {
		        printf('WARNING: DB Blocked (>10 min) SPID: %s STATUS: %s', $row['Blocking SPID'], $row['Blocked SPID Status']);
		        exit(1);
		} else {
                        mssql_close($conn);
                        echo 'NORMAL: no blocking reported';
                        exit(0);
                }
        }
}

mssql_close($conn);
echo 'NORMAL: no blocking reported';
exit(0);
?>
