# Package

version       = "0.1.0"
author        = "liquid600pgm"
description   = "A safe, high-level, optimized OpenGL wrapper"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.0.6"
requires "nimterop >= 0.4.4"
requires "glm >= 1.1.1"


# Tasks

from os import walkDirRec, splitFile

task buildDocs, "rebuilds documentation to the docs/ folder for GitHub Pages":
  echo "-- creating doc directory"
  rmDir "docs"
  mkDir "docs"

  echo "-- building docs for aglet.nim"
  selfExec "doc " &
    "--project --index:on -o:docs/ " &
    "--git.url:https://github.com/liquid600pgm/aglet " &
    "--git.commit:0.1.0 " &
    "src/aglet.nim"

  echo "-- creating index.html"
  cpFile "docs/aglet.html", "docs/index.html"

  echo "-- removing leftover .idx files"
  for name in walkDirRec "docs":
    let (_, _, ext) = name.splitFile
    if ext == ".idx":
      echo " : ", name
      rmFile name

  echo "-- done!"
