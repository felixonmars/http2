{-# LANGUAGE BangPatterns, OverloadedStrings #-}

module Network.HPACK.Table.Entry (
  -- * Type
    Size
  , Entry
  , HeaderValue
  -- * Header and Entry
  , toEntry
  , fromEntry
  -- * Getters
  , entrySize
  , entryHeaderName
  , entryHeaderValue
  -- * For initialization
  , dummyEntry
  , maxNumbers
  ) where

import Data.CaseInsensitive (foldedCase)
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Network.HTTP.Types (HeaderName, Header)

----------------------------------------------------------------

-- | Size in bytes.
type Size = Int

-- | Type for table entry.
type Entry = (Size,Header)

-- | Header value
type HeaderValue = ByteString

----------------------------------------------------------------

headerSizeMagicNumber :: Size
headerSizeMagicNumber = 32

headerSize :: Header -> Size
headerSize (k,v) = BS.length (foldedCase k) + BS.length v + headerSizeMagicNumber

----------------------------------------------------------------

-- | From 'Header' to 'Entry'.
toEntry :: Header -> Entry
toEntry h = (siz,h)
  where
    !siz = headerSize h

-- | From 'Entry' to 'Header'.
fromEntry :: Entry -> Header
fromEntry = snd

----------------------------------------------------------------

-- | Getting the size of 'Entry'.
entrySize :: Entry -> Size
entrySize = fst

-- | Getting 'HeaderName'.
entryHeaderName :: Entry -> HeaderName
entryHeaderName (_,(k,_)) = k

-- | Getting 'HeaderValue'. (FIXME)
entryHeaderValue :: Entry -> ByteString
entryHeaderValue (_,(_,v)) = v

----------------------------------------------------------------

-- | Dummy 'Entry' to initialize a table.
dummyEntry :: Entry
dummyEntry = (0,("",""))

maxNumbers :: Size -> Int
maxNumbers siz = siz `div` headerSizeMagicNumber