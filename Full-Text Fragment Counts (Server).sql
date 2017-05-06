/*

This script reports on the number of fragments in the fulltext catalog for each database on a server.  If fulltext catalogs are fragmented, keyword 
search performance can be affected.  Ideally the fragment count should stay below 10 for a given database.  If fragmentation is high, a maintenance 
script can be run to eliminate fragmentation.

*/

DECLARE @SQL nvarchar(max)
DECLARE @x INT
DECLARE @i INT = 1
DECLARE @iMax INT
DECLARE @databaseName nvarchar(50)

SET NOCOUNT ON

--Create work table with database names and fragment counts
CREATE TABLE #workTable(
ID INT IDENTITY (1,1) PRIMARY KEY,
Database_Name   SYSNAME,
FT_Fragment_Count INT 
)

--add databases with full-text catalogs to the work table
INSERT INTO #workTable (Database_Name)
SELECT name from sys.databases WITH (NOLOCK) WHERE name LIKE 'EDDS%' AND name NOT IN ('EDDS', 'EDDSPerformance', 'EDDSResource', 'EDDS1014823', 'EDDS1015024') --add additional databases to ignore here if desired
					
SELECT @iMax = MAX(ID) FROM #workTable

--loop to set fragment counts and delete databases from work table that do not contain a FTC for Relativity
WHILE @i <= @iMax
BEGIN
	SET @databaseName = (SELECT Database_Name FROM #workTable WHERE ID = @i)
	SET @SQL = 'SELECT @fragCount = COUNT(fragment_id) FROM @databaseName.sys.fulltext_index_fragments WITH (NOLOCK)'
	SET @SQL = REPLACE(@SQL, '@databaseName', @databaseName)
	EXECUTE sp_executesql @SQL, N'@fragCount INT OUTPUT', @fragCount = @x OUTPUT

	UPDATE #workTable
	SET FT_Fragment_Count = @x
	WHERE ID = @i

	--Delete the database from the work table if it does not contain a full text catalog for Relativity
	SET @SQL = 'IF NOT EXISTS (SELECT 1 FROM [@databaseName].[sys].[fulltext_catalogs] WHERE name = ''@databaseName'')
					DELETE FROM #workTable WHERE Database_Name = ''@databaseName'''
	SET @SQL = REPLACE(@SQL, '@databaseName', @databaseName)
	EXECUTE sp_executesql @SQL
	SET @i = @i + 1
END

SELECT Database_Name, FT_Fragment_Count FROM #workTable ORDER BY FT_Fragment_Count DESC
DROP TABLE #workTable