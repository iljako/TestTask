USE TestDB
GO
/*
CREATE TYPE XmlDoc 
   AS TABLE
(id INT,
parentid INT,
nodetype INT,
localname varchar(max),
prefix varchar(max),
namespaceuri varchar(max),
datatype varchar(max), 
prev varchar(max),
text varchar(max))
GO
*/

CREATE OR ALTER FUNCTION XMLNodetoJSON2(@parent int, @XmlDoc1 XmlDoc READONLY, @lasttype int) --@lasttype 0-dict, >1-array
RETURNS varchar(max)	
BEGIN
	DECLARE @id int, @parentid int, @localname varchar(max), @text varchar(max), @gr_count int, @prev int, @gr_max int;
	DECLARE @ret_value varchar(max);
	DECLARE xmlnode CURSOR FOR select id, parentid, count(localname) OVER (partition by localname, parentid) as gr_count, localname, text, prev,max(id) OVER (partition by localname, parentid) as gr_max from @XmlDoc1 WHERE parentid = @parent order by parentid, localname,prev
	OPEN xmlnode
	FETCH xmlnode INTO @id, @parentid, @gr_count, @localname, @text, @prev, @gr_max
	IF @gr_count > 1
		SET @ret_value = CONCAT('[', @ret_value);
	WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @prev IS NOT NULL
				SET @ret_value = CONCAT(@ret_value, ',')
			
			IF (Select top 1 id from @XmlDoc1 WHERE text IS NOT NULL AND parentid = @id) IS NOT NULL
				BEGIN
					IF @text IS NULL
					BEGIN
						IF @gr_count > 1
							SET @ret_value = CONCAT(@ret_value, '{"',  @localname, '":');
						ELSE
							SET @ret_value = CONCAT(@ret_value, '"',  @localname, '":');
					END
				END
			ELSE IF (Select top 1 id from @XmlDoc1 WHERE text IS NOT NULL AND parentid = @id) IS NOT NULL
				BEGIN
					IF @text IS NULL
						SET @ret_value = CONCAT(@ret_value, '"',  @localname, '":');
				END
			ELSE
				BEGIN
					IF @text IS NULL
						BEGIN
							SET @ret_value = CONCAT(@ret_value, '"',  @localname, '":');
						END
					ELSE
					BEGIN
						IF @lasttype > 1
							SET @ret_value = CONCAT(@ret_value, '"',  @text, '"}');
						ELSE
							SET @ret_value = CONCAT(@ret_value, '"',  @text, '"');
					END
					
				END

			SET @ret_value = CONCAT(@ret_value, dbo.XMLNodetoJSON2(@id, @XmlDoc1,@gr_count));
		
			if @id = @gr_max and @gr_count > 1
				SET @ret_value = CONCAT(@ret_value,']');

			FETCH NEXT FROM xmlnode INTO @id, @parentid, @gr_count, @localname, @text, @prev, @gr_max
		
		END
	CLOSE xmlnode

	RETURN @ret_value;
END
GO


CREATE OR ALTER PROCEDURE XMLtoJSON
    @test varchar(max)    
AS
	DECLARE @xml xml;
	SET @xml = @test;
	DECLARE @XmlDoc XmlDoc;
	DECLARE @DocHandle INT;
	EXEC sp_xml_preparedocument @DocHandle OUTPUT, @xml;
	INSERT  INTO @XmlDoc  (id,parentid,nodetype,localname,prefix,namespaceuri,datatype, prev, text)
	SELECT id,parentid,nodetype,localname,prefix,namespaceuri,datatype, prev, text  FROM OPENXML (@DocHandle,'/*');
	EXEC sp_xml_removedocument @DocHandle;
	
	declare @res varchar(max);
	SET @res = (SELECT localname FROM @XmlDoc Where id = 0);
	--SELECT @res = CONCAT('{"', @res,'":',dbo.XMLNodetoJSON2(0, @XmlDoc), '}');
	SELECT @res = CONCAT('{"', @res,'":{',dbo.XMLNodetoJSON2(0, @XmlDoc,0), '}}');
	Select @res;
	
	select id, parentid, count(localname) OVER (partition by localname, parentid) as gr_count, localname, text, prev,max(id) OVER (partition by localname, parentid) as gr_max from @XmlDoc  order by parentid, localname,prev
GO

exec XMLtoJSON '<user><name>иван</name><phones><phone>91111</phone><phone>34324</phone></phones></user>';
