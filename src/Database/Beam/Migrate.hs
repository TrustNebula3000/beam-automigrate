{-# LANGUAGE FlexibleContexts     #-}
{-# LANGUAGE LambdaCase           #-}
module Database.Beam.Migrate where

import           Control.Monad.State.Strict     ( StateT
                                                , execStateT
                                                )
import           Control.Monad.IO.Class         ( liftIO
                                                , MonadIO
                                                )
import           Data.Text                      ( Text )

import           GHC.Generics

import           Database.Beam                  ( MonadBeam )
import           Database.Beam.Schema           ( DatabaseSettings )

import           Database.Beam.Migrate.Generic
import           Database.Beam.Migrate.Types

--
-- Potential API (sketched)
--

-- | Turns a Beam's 'DatabaseSettings' into a 'Schema'.
fromDbSettings :: (Generic (DatabaseSettings be db), GSchema (Rep (DatabaseSettings be db)))
               => DatabaseSettings be db
               -> Schema
fromDbSettings = gSchema . from

-- | Interpret a single 'Edit'.
-- NOTE(adn) Until we figure out whether or not we want to use Beam's Query
-- builder, this can for now yield the raw SQL fragment, for simplicity, which
-- can later be interpreted via 'Database.Beam.Query.CustomSQL'.
-- For now this is /very/ naive, we don't want to write custom, raw SQL fragments.
evalEdit :: Edit -> Text
evalEdit = \case
  ColumnAdded tblName colName _col ->
    "ALTER TABLE \"" <> tableName tblName <> "\" ADD COLUMN \"" <> columnName colName <> "\""
  ColumnRemoved tblName colName ->
    "ALTER TABLE \"" <> tableName tblName <> "\" DROP COLUMN \"" <> columnName colName <> "\""
  TableAdded tblName _tbl -> "CREATE TABLE \"" <> tableName tblName <> "\" ()"
  TableRemoved tblName    -> "DROP TABLE \"" <> tableName tblName <> "\""

-- | Computes the diff between two 'Schema's, either failing with a 'DiffError'
-- or returning the list of 'Edit's necessary to turn the first into the second.
diff :: Schema -> Schema -> Either DiffError [Edit]
diff _old _new = undefined

type Migration m = StateT [Edit] m ()

-- | Runs the input 'Migration'.
runMigration :: (MonadBeam be m, MonadIO m) => Migration m -> m ()
runMigration m = do
  migs <- execStateT m mempty
  liftIO $ print (map evalEdit migs)