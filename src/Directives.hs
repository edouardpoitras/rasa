{-# LANGUAGE OverloadedStrings, Rank2Types #-}
module Directives (
                    Directive(..)
                  , Continue(..)
                  , handleEvent
                  ) where

import State
import TextLens
import Buffer

import qualified Data.Text as T
import Control.Lens
import Control.Monad.State (execState)
import Data.List.Extra (dropEnd)
import Types

handleEvent :: Continue -> Continue
handleEvent (Continue exts dirs st) = Continue exts dirs $ foldl (flip doEvent) st dirs

nonEmpty :: Prism' T.Text T.Text
nonEmpty = prism id $ \t ->
    if T.null t
       then Left t
       else Right t

someText :: (T.Text -> Identity T.Text) -> St -> Identity St
someText = focusedBuf.text.nonEmpty

deleteChar :: St -> St
deleteChar = execState $ do
    curs <- use (focusedBuf.cursor)
    focusedBuf.text.range (curs-1) curs .= ""
    focusedBuf %= moveCursorBy (-1)

findNext :: T.Text -> Buffer Offset -> Buffer Offset
findNext txt = useCountFor (withOffset after.tillNext txt) moveCursorBy

findPrev :: T.Text -> Buffer Offset -> Buffer Offset
findPrev txt = useCountFor (withOffset before.intillPrev txt) moveCursorBackBy

doEvent :: Directive -> St -> St
doEvent (Append txt) =  focusedBuf %~ appendText txt
doEvent DeleteChar = deleteChar
doEvent KillWord =  someText %~ (T.unwords . dropEnd 1 . T.words)
doEvent (MoveCursor n) =  focusedBuf %~ moveCursorBy n
doEvent (MoveCursorCoordBy coords) =  focusedBuf %~ moveCursorCoordBy coords
doEvent StartOfLine = focusedBuf %~ findPrev "\n"
doEvent EndOfLine = focusedBuf %~ findNext "\n"
doEvent StartOfBuffer = focusedBuf %~ moveCursorTo 0
doEvent EndOfBuffer = focusedBuf %~ useCountFor text moveCursorTo
doEvent (FindNext txt) = focusedBuf %~ findNext txt
doEvent (FindPrev txt) = focusedBuf %~ findPrev txt
doEvent Exit = id

doEvent (SwitchBuf n) = execState $ do
    currentBuffer <- use focused
    numBuffers <- use (buffers.to length)
    focused .= (n + currentBuffer) `mod` numBuffers

