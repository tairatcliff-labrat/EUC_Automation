--Delete history if the database exists.
USE [msdb]
IF EXISTS (SELECT * FROM sys.sysdatabases WHERE name='XXXXXAIRWATCHDBXXXXX')
BEGIN
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'XXXXXAIRWATCHDBXXXXX'
END
--Delete database if the database exists.
USE [master]
IF EXISTS (SELECT * FROM sys.sysdatabases WHERE name='XXXXXAIRWATCHDBXXXXX')
BEGIN
DROP DATABASE [XXXXXAIRWATCHDBXXXXX]
END