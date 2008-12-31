-- File created: 2008-11-07 17:30:16

{-# LANGUAGE MultiParamTypeClasses, FlexibleInstances #-}

module Data.Trie.Base.Map where

import Control.Arrow ((***), first, second)
import Data.Function (on)
import Data.List     (foldl', foldl1', mapAccumL, nubBy, partition, sortBy)
import Data.Ord      (comparing)
import qualified Data.IntMap as IM
import qualified Data.Map    as M

import Data.Trie.Util (both)

class Map m k where
   -- Like an Eq instance over k, but should compare on the same type as 'm'
   -- does. In most cases this can be defined just as 'const (==)'.
   eqCmp :: m k a -> k -> k -> Bool

   empty     ::                     m k a
   singleton ::           k -> a -> m k a
   doubleton :: k -> a -> k -> a -> m k a

   null   :: m k a -> Bool
   lookup :: m k a -> k -> Maybe a

   insert     ::                  m k a -> k -> a -> m k a
   insertWith :: (a -> a -> a) -> m k a -> k -> a -> m k a

   update :: (a -> Maybe a) -> m k a -> k -> m k a
   adjust :: (a -> a)       -> m k a -> k -> m k a
   delete ::                   m k a -> k -> m k a

   difference          ::                             m k a -> m k b -> m k a
   unionWith           ::      (a -> a -> a)       -> m k a -> m k a -> m k a
   differenceWith      ::      (a -> b -> Maybe a) -> m k a -> m k b -> m k a
   intersectionWith    ::      (a -> b -> c)       -> m k a -> m k b -> m k c
   unionWithKey        :: (k -> a -> a -> a)       -> m k a -> m k a -> m k a
   differenceWithKey   :: (k -> a -> b -> Maybe a) -> m k a -> m k b -> m k a
   intersectionWithKey :: (k -> a -> b -> c)       -> m k a -> m k b -> m k c

   map             ::      (a -> b) -> m k a -> m k b
   mapWithKey      :: (k -> a -> b) -> m k a -> m k b
   mapAccum        :: (a ->      b -> (a,c)) -> a -> m k b -> (a, m k c)
   mapAccumWithKey :: (a -> k -> b -> (a,c)) -> a -> m k b -> (a, m k c)

   foldValues :: (a -> b -> b) -> b -> m k a -> b

   toList       :: m k a -> [(k,a)]
   fromList     ::                  [(k,a)] -> m k a
   fromListWith :: (a -> a -> a) -> [(k,a)] -> m k a

   isSubmapOfBy :: (a -> b -> Bool) -> m k a -> m k b -> Bool

   singletonView :: m k a -> Maybe (k,a)

   singleton = insert empty
   doubleton = (insert .) . singleton

   insert = insertWith const

   adjust f = update (Just . f)
   delete   = update (const Nothing)

   difference       = differenceWith (\_ _ -> Nothing)
   unionWith        = unionWithKey        . const
   differenceWith   = differenceWithKey   . const
   intersectionWith = intersectionWithKey . const

   map                 = mapWithKey . const
   mapAccum        f   = mapAccumWithKey (const . f)
   mapAccumWithKey f z =
      second fromList .
         mapAccumL (\a (k,v) -> fmap ((,) k) (f a k v)) z .
      toList

   singletonView m =
      case toList m of
           [x] -> Just x
           _   -> Nothing

-- Minimal complete definition: toAscList or toDescList, and splitLookup
--
-- fromDistinctAscList and fromDistinctAscList are only used in the default
-- definitions of splitLookup, minViewWithKey and maxViewWithKey, and default
-- to fromList
class Map m k => OrdMap m k where
   -- Like an Ord instance over k, but should compare on the same type as 'm'
   -- does. In most cases this can be defined just as 'const compare'.
   ordCmp :: m k a -> k -> k -> Ordering

   toAscList            :: m k a -> [(k,a)]
   toDescList           :: m k a -> [(k,a)]
   fromDistinctAscList  :: [(k,a)] -> m k a
   fromDistinctDescList :: [(k,a)] -> m k a

   splitLookup :: m k a -> k -> (m k a, Maybe a, m k a)
   split       :: m k a -> k -> (m k a,          m k a)

   minViewWithKey :: m k a -> (Maybe (k,a), m k a)
   maxViewWithKey :: m k a -> (Maybe (k,a), m k a)

   findPredecessor :: m k a -> k -> Maybe (k,a)
   findSuccessor   :: m k a -> k -> Maybe (k,a)

   mapAccumAsc         :: (a ->      b -> (a,c)) -> a -> m k b -> (a, m k c)
   mapAccumAscWithKey  :: (a -> k -> b -> (a,c)) -> a -> m k b -> (a, m k c)
   mapAccumDesc        :: (a ->      b -> (a,c)) -> a -> m k b -> (a, m k c)
   mapAccumDescWithKey :: (a -> k -> b -> (a,c)) -> a -> m k b -> (a, m k c)

   toAscList  = reverse . toDescList
   toDescList = reverse . toAscList
   fromDistinctAscList  = fromList
   fromDistinctDescList = fromList

   split m k = let (a,_,b) = splitLookup m k in (a,b)

   minViewWithKey m =
      case toAscList m of
           []     -> (Nothing, m)
           (x:xs) -> (Just x, fromDistinctAscList xs)

   maxViewWithKey m =
      case toDescList m of
           []     -> (Nothing, m)
           (x:xs) -> (Just x, fromDistinctDescList xs)

   findPredecessor m x = fst . maxViewWithKey . fst . split m $ x
   findSuccessor   m x = fst . minViewWithKey . snd . split m $ x

   mapAccumAsc  f = mapAccumAscWithKey  (const . f)
   mapAccumDesc f = mapAccumDescWithKey (const . f)
   mapAccumAscWithKey f z =
      second fromList .
         mapAccumL (\a (k,v) -> fmap ((,) k) (f a k v)) z .
      toAscList
   mapAccumDescWithKey f z =
      second fromList .
         mapAccumL (\a (k,v) -> fmap ((,) k) (f a k v)) z .
      toDescList

newtype AList k v = AL [(k,v)]

instance Eq k => Map AList k where
   eqCmp = const (==)

   empty              = AL []
   singleton k v      = AL [(k,v)]
   doubleton a b p q  = AL [(a,b),(p,q)]

   null (AL xs)       = Prelude.null xs
   lookup (AL xs) x   = Prelude.lookup x xs

   insertWith f (AL xs) k v =
      let (old, ys) = deleteAndGetBy ((== k).fst) xs
       in case old of
               Just (_,v2) -> AL$ (k, f v v2) : ys
               Nothing     -> AL$ (k,   v)    : xs

   update f orig@(AL xs) k =
      let (old, ys) = deleteAndGetBy ((== k).fst) xs
       in case old of
               Nothing    -> orig
               Just (_,v) ->
                  case f v of
                       Nothing -> AL             ys
                       Just v' -> AL $ (k, v') : ys

   delete (AL xs) k = AL$ deleteBy (\a (b,_) -> a == b) k xs

   unionWithKey f (AL xs) (AL ys) =
      AL$ updateFirstsBy (\(k,x) (_,y) -> fmap ((,) k) (Just $ f k x y))
                         (\x y -> fst x == fst y)
                         xs ys

   differenceWithKey f (AL xs) (AL ys) =
      AL$ updateFirstsBy (\(k,x) (_,y) -> fmap ((,) k) (f k x y))
                         (\x y -> fst x == fst y)
                         xs ys

   intersectionWithKey f_ (AL xs_) (AL ys_) = AL$ go f_ xs_ ys_
    where
      go _ [] _ = []
      go f ((k,x):xs) ys =
         let (my,ys') = deleteAndGetBy ((== k).fst) ys
          in case my of
                  Just (_,y) -> (k, f k x y) : go f xs ys'
                  Nothing    ->                go f xs ys

   mapWithKey f (AL xs) = AL $ Prelude.map (\(k,v) -> (k, f k v)) xs

   mapAccumWithKey f z (AL xs) =
      second AL $ mapAccumL (\a (k,v) -> let (a',v') = f a k v
                                          in (a', (k, v')))
                            z xs

   foldValues f z (AL xs) = foldr (f.snd) z xs

   toList (AL xs)      = xs
   fromList            = AL . nubBy ((==) `on` fst)
   fromListWith f_ xs_ = AL (go f_ xs_)
    where
      go _ []     = []
      go f (x:xs) =
         let (as,bs) = partition (((==) `on` fst) x) xs
          in (fst x, foldl1' f . Prelude.map snd $ x:as) : go f bs

   isSubmapOfBy f_ (AL xs_) (AL ys_) = go f_ xs_ ys_
    where
      go _ []         _  = True
      go f ((k,x):xs) ys =
         let (my,ys') = deleteAndGetBy ((== k).fst) ys
          in case my of
                  Just (_,y) -> f x y && go f xs ys'
                  Nothing    -> False

instance Ord k => OrdMap AList k where
   ordCmp = const compare

   toAscList  = sortBy (       comparing fst) . toList
   toDescList = sortBy (flip $ comparing fst) . toList

   splitLookup (AL xs) k =
      let (ls,gs) = partition ((< k).fst) xs
       in case gs of
               (k',x):gs' | k' == k -> (AL ls, Just x, AL gs')
               _                    -> (AL ls, Nothing, AL gs)

deleteAndGetBy :: (a -> Bool) -> [a] -> (Maybe a, [a])
deleteAndGetBy = go []
 where
   go ys _ []     = (Nothing, ys)
   go ys p (x:xs) =
      if p x
         then (Just x, xs ++ ys)
         else go (x:ys) p xs

-- These two are from Data.List, just with more general type signatures...
deleteBy :: (a -> b -> Bool) -> a -> [b] -> [b]
deleteBy _  _ []     = []
deleteBy eq x (y:ys) = if x `eq` y then ys else y : deleteBy eq x ys

deleteFirstsBy :: (a -> b -> Bool) -> [a] -> [b] -> [a]
deleteFirstsBy = foldl' . flip . deleteBy . flip

updateFirstsBy :: (a -> b -> Maybe a) -> (a -> b -> Bool) -> [a] -> [b] -> [a]
updateFirstsBy _ _  []     _  = []
updateFirstsBy f eq (x:xs) ys =
   let (my,ys') = deleteAndGetBy (eq x) ys
    in case my of
            Nothing -> x : updateFirstsBy f eq xs ys
            Just y  ->
               case f x y of
                    Just z  -> z : updateFirstsBy f eq xs ys'
                    Nothing ->     updateFirstsBy f eq xs ys'

instance Ord k => Map M.Map k where
   eqCmp = const (==)

   empty        = M.empty
   singleton    = M.singleton

   null         = M.null
   lookup       = flip M.lookup

   insertWith f m k v = M.insertWith' f k v m

   update = flip . M.update
   adjust = flip . M.adjust
   delete = flip   M.delete

   difference          = M.difference
   unionWith           = M.unionWith
   differenceWith      = M.differenceWith
   intersectionWith    = M.intersectionWith
   unionWithKey        = M.unionWithKey
   differenceWithKey   = M.differenceWithKey
   intersectionWithKey = M.intersectionWithKey

   map             = M.map
   mapWithKey      = M.mapWithKey
   mapAccum        = M.mapAccum
   mapAccumWithKey = M.mapAccumWithKey

   foldValues = M.fold

   toList       = M.toList
   fromList     = M.fromList
   fromListWith = M.fromListWith

   isSubmapOfBy = M.isSubmapOfBy

   singletonView m =
      case M.minViewWithKey m of
           Just (a,others) | M.null others -> Just a
           _                               -> Nothing

instance Ord k => OrdMap M.Map k where
   ordCmp = const compare

   toAscList            = M.toAscList
   fromDistinctAscList  = M.fromDistinctAscList
   fromDistinctDescList = fromDistinctAscList . reverse

   splitLookup = flip M.splitLookup
   split       = flip M.split

   minViewWithKey m = maybe (Nothing, m) (first Just) (M.minViewWithKey m)
   maxViewWithKey m = maybe (Nothing, m) (first Just) (M.maxViewWithKey m)

   mapAccumAsc        = M.mapAccum
   mapAccumAscWithKey = M.mapAccumWithKey

   -- mapAccumDesc waiting on http://hackage.haskell.org/trac/ghc/ticket/2769

newtype IMap k v = IMap (IM.IntMap v)

instance Enum k => Map IMap k where
   eqCmp = const ((==) `on` fromEnum)

   empty               = IMap IM.empty
   singleton k v       = IMap$ IM.singleton (fromEnum k) v

   null (IMap m)       = IM.null m
   lookup (IMap m) k   = IM.lookup (fromEnum k) m

   insertWith f (IMap m) k v = IMap$ IM.insertWith f (fromEnum k) v m

   update f (IMap m) k = IMap$ IM.update f (fromEnum k) m
   adjust f (IMap m) k = IMap$ IM.adjust f (fromEnum k) m
   delete   (IMap m) k = IMap$ IM.delete   (fromEnum k) m

   difference         (IMap x) (IMap y) = IMap$ IM.difference         x y
   unionWith        f (IMap x) (IMap y) = IMap$ IM.unionWith        f x y
   differenceWith   f (IMap x) (IMap y) = IMap$ IM.differenceWith   f x y

   -- http://hackage.haskell.org/trac/ghc/ticket/2644
   --intersectionWith f (IMap x) (IMap y) = IMap$ IM.intersectionWith f x y
   intersectionWith = undefined

   unionWithKey      f (IMap x) (IMap y) =
      IMap$ IM.unionWithKey (f . toEnum) x y
   differenceWithKey f (IMap x) (IMap y) =
      IMap$ IM.differenceWithKey (f . toEnum) x y

   -- http://hackage.haskell.org/trac/ghc/ticket/2644
   --intersectionWithKey f (IMap x) (IMap y) =
   --   IMap$ IM.intersectionWithKey (f . toEnum) x y
   intersectionWithKey = undefined

   map             f   (IMap x) = IMap$ IM.map f x
   mapWithKey      f   (IMap x) = IMap$ IM.mapWithKey (f . toEnum) x
   mapAccum        f z (IMap x) = second IMap$ IM.mapAccum f z x
   mapAccumWithKey f z (IMap x) =
      second IMap$ IM.mapAccumWithKey (\a -> f a . toEnum) z x

   foldValues f z (IMap m) = IM.fold f z m

   toList (IMap m) = Prelude.map (first toEnum) . IM.toList $ m
   fromList        = IMap . IM.fromList       . Prelude.map (first fromEnum)
   fromListWith f  = IMap . IM.fromListWith f . Prelude.map (first fromEnum)

   isSubmapOfBy f (IMap x) (IMap y) = IM.isSubmapOfBy f x y

   singletonView (IMap m) =
      case IM.minViewWithKey m of
           Just (a,others) | IM.null others -> Just (first toEnum a)
           _                                -> Nothing

instance Enum k => OrdMap IMap k where
   ordCmp = const (compare `on` fromEnum)

   toAscList (IMap m)   = Prelude.map (first toEnum) . IM.toAscList $ m
   fromDistinctAscList  =
      IMap . IM.fromDistinctAscList . Prelude.map (first fromEnum)
   fromDistinctDescList = fromDistinctAscList . reverse

   splitLookup (IMap m) =
      (\(a,b,c) -> (IMap a, b, IMap c)) . flip IM.splitLookup m . fromEnum

   split (IMap m) = both IMap . flip IM.split m . fromEnum

   minViewWithKey o@(IMap m) =
      maybe (Nothing, o) (Just . first toEnum *** IMap) (IM.minViewWithKey m)
   maxViewWithKey o@(IMap m) =
      maybe (Nothing, o) (Just . first toEnum *** IMap) (IM.maxViewWithKey m)

   mapAccumAsc        f z (IMap m) = second IMap $ IM.mapAccum f z m
   mapAccumAscWithKey f z (IMap m) =
      second IMap $ IM.mapAccumWithKey (\a k -> f a (toEnum k)) z m

   -- mapAccumDesc waiting on http://hackage.haskell.org/trac/ghc/ticket/2769
