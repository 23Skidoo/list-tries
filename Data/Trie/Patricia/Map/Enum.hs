-- File created: 2008-12-29 12:42:12

-- A map with lists of enumerable elements as keys, based on a Patricia trie.
--
-- Note that those operations which require an ordering, such as 'toAscList',
-- do not compare the elements themselves, but rather their Int representation
-- after 'fromEnum'.

{-# LANGUAGE CPP #-}

#include "exports.h"

module Data.Trie.Patricia.Map.Enum (MAP_EXPORTS) where

import Data.Trie.Base.Map            (WrappedIntMap)
import Data.Trie.Patricia.Map hiding (TrieMap)
import qualified Data.Trie.Patricia.Map as Base
import Prelude hiding (filter, foldr, lookup, map, null)

type TrieMap = Base.TrieMap WrappedIntMap
