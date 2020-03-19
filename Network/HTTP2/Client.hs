{-# LANGUAGE OverloadedStrings #-}

-- | HTTP\/2 client library.
--
--  Example:
--
-- > {-# LANGUAGE OverloadedStrings #-}
-- > module Main where
-- >
-- > import qualified Control.Exception as E
-- > import qualified Data.ByteString.Char8 as C8
-- > import Network.HTTP.Types
-- > import Network.Run.TCP (runTCPClient) -- network-run
-- >
-- > import Network.HTTP2.Client
-- >
-- > server :: String
-- > server = "127.0.0.1"
-- >
-- > authority :: C8.ByteString
-- > authority = C8.pack server
-- >
-- > main :: IO ()
-- > main = runTCPClient server "80" runHTTP2Client
-- >   where
-- >     runHTTP2Client s = E.bracket (allocSimpleConfig s 4096)
-- >                                  freeSimpleConfig
-- >                                  (\conf -> run conf "http" authority client)
-- >     client sendRequest = do
-- >         let req = requestNoBody methodGet "/" []
-- >         sendRequest req $ \rsp -> do
-- >             print rsp
-- >             getResponseBodyChunk rsp >>= C8.putStrLn

module Network.HTTP2.Client (
  -- * Runner
    run
  , Scheme
  , Authority
  -- * Runner arguments
  , Config(..)
  , allocSimpleConfig
  , freeSimpleConfig
  -- * HTTP\/2 client
  , Client
  -- * Request
  , Request
  , requestNoBody
  , requestFile
  , requestStreaming
  , requestBuilder
  , Method
  , Path
  -- * Response
  , Response
  -- ** Accessing response
  , responseStatus
  , responseHeaders
  , responseBodySize
  , getResponseBodyChunk
  , getResponseTrailers
  -- * Types
  , FileSpec(..)
  , FileOffset
  , ByteCount
  -- * RecvN
  , defaultReadN
  -- * Position read for files
  , PositionReadMaker
  , PositionRead
  , Sentinel(..)
  , defaultPositionReadMaker
  ) where

import Data.ByteString (ByteString)
import Data.ByteString.Builder (Builder)
import Data.IORef (readIORef)
import Network.HTTP.Types

import Network.HPACK
import Network.HTTP2.Arch
import Network.HTTP2.Client.Types
import Network.HTTP2.Client.Run

----------------------------------------------------------------

-- | Creating request without body.
requestNoBody :: Method -> Path -> RequestHeaders -> Request
requestNoBody m p hdr = Request $ OutObj hdr' OutBodyNone defaultTrailersMaker
  where
    hdr' = addHeaders m p hdr

-- | Creating request with file.
requestFile :: Method -> Path -> RequestHeaders -> FileSpec -> Request
requestFile m p hdr fileSpec = Request $ OutObj hdr' (OutBodyFile fileSpec) defaultTrailersMaker
  where
    hdr' = addHeaders m p hdr

-- | Creating request with builder.
requestBuilder :: Method -> Path -> RequestHeaders -> Builder -> Request
requestBuilder m p hdr builder = Request $ OutObj hdr' (OutBodyBuilder builder) defaultTrailersMaker
  where
    hdr' = addHeaders m p hdr

-- | Creating request with streaming.
requestStreaming :: Method -> Path -> RequestHeaders
                 -> ((Builder -> IO ()) -> IO () -> IO ())
                 -> Request
requestStreaming m p hdr strmbdy = Request $ OutObj hdr' (OutBodyStreaming strmbdy) defaultTrailersMaker
  where
    hdr' = addHeaders m p hdr


addHeaders :: Method -> Path -> RequestHeaders -> RequestHeaders
addHeaders m p hdr = (":method", m) : (":path", p) : hdr

----------------------------------------------------------------

responseStatus :: Response -> Maybe Status
responseStatus (Response rsp) = getStatus $ inpObjHeaders rsp

responseHeaders :: Response -> HeaderTable
responseHeaders (Response rsp) = inpObjHeaders rsp

responseBodySize :: Response -> Maybe Int
responseBodySize (Response rsp) = inpObjBodySize rsp

getResponseBodyChunk :: Response -> IO ByteString
getResponseBodyChunk (Response rsp) = inpObjBody rsp

getResponseTrailers :: Response -> IO (Maybe HeaderTable)
getResponseTrailers (Response rsp) = readIORef (inpObjTrailers rsp)
