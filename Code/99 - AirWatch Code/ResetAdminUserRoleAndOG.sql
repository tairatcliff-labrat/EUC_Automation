--Script updates role for Administrator

-- Resets Administrator user password to AutomationTesting01!
--PRINT 'Resetting password for administrator.'
--UPDATE [dbo].[CoreUser]
--SET [Password] = 'tJRiZmwpk1pZtifjOFC7YGr4OIsHtcmWGo/Rr3tlAJ+HK92wuNMEkEdJXNeLIlBDGd9mw3Up5qlSCBGrNNH0GQ=='
--,[PasswordSalt] = 'vtsXUfGMQ46d+9QSMI+DrUaxvF0='
--WHERE CoreUserID = 52

PRINT 'Setting RootLocationGroupID for administrator to Global.'
UPDATE dbo.CoreUser 
SET RootLocationGroupID = 7
WHERE CoreUserID = 52


UPDATE dbo.UserLink
SET IsActive = 0
WHERE CoreUserID = 52

UPDATE dbo.UserLink
SET IsActive = 1
WHERE CoreUserID = 52 AND RoleID = 3 AND LocationGroupID = 7

IF @@ROWCOUNT = 0
      BEGIN
            SET IDENTITY_INSERT dbo.UserLink ON
            INSERT INTO dbo.UserLink
            (
                  --UserLinkID,
                  CoreUserID,
                  RoleID,
                  LocationGroupID,
                  IsActive,
                  UserLinkSource,
                  SecretKey
            )
            VALUES
            (
                  --NewID(),-- UserLinkID - int
                  52, -- CoreUserID - int
                  3, -- RoleID - int
                  7, -- LocationGroupID - int
                  1, -- IsActive - bit
                  0, -- UserLinkSource - int
                  NULL -- SecretKey - nvarchar
            )
            SET IDENTITY_INSERT dbo.UserLink OFF
      END