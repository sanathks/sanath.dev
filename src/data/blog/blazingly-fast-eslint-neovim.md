---
author: Sanath Samarasinghe
pubDatetime: 2024-01-20T00:00:00Z
modDatetime:
title: How to make eslint and fixers blazingly fast in neovim
featured: true
draft: false
tags:
  - neovim
  - eslint
  - development
  - productivity
description: A guide to setting up ALE with eslint_d for lightning-fast linting in Neovim
---

Recently I switched to Neovim from WebStorm. It wasn't a smooth transition, but enjoyable. Vim is always fun to work with. Basically, you can build your own IDE or working environment. The only thing bugging me was the linting and fixers of this transition. I've tried a few plugins like null-ls, which didn't work as expected in my case. Then I found out about the ALE.

## ALE

ALE (Asynchronous Lint Engine), yet stable and powerful plugin for the linting. The installation is pretty straightforward. You can use any package manager you use to install the plugin. In my case, I've used packer:

```lua
return require('packer').startup(function(use)
  use 'dense-analysis/ale'
end)
```

By default, ALE does not act fast on linting and fixing.

## How to make ALE faster

The reason has been it searches the executable to run. Hence the solution is to set the executable in the vim config.

```vim
let b:ale_javascript_eslint_executable = 'path/to/eslint'
let b:ale_javascript_eslint_use_global = 1
```

There are two issues with this approach. One is hardcoding eslint path. But it will not always work since different projects use a different version of eslint. The second one is the eslint runs each file separately, hence nodejs startup time and module loading time make it slow. But we can fix these two issues quickly with eslint_d.

## eslint_d

In eslint_d it starts a server in the background and keeps separate instances for each working directory. Plus, it's using the current version of eslint, which is in node_modules if it's not found, it will fall back to the default version it ships with.

## How to config ale with eslint_d

First, you need to install eslint_d:

```bash
npm install -g eslint_d
```

Then you need to set the `ale_javascript_eslint_executable` for ale:

```vim
let b:ale_javascript_eslint_executable = 'eslint_d'
let b:ale_javascript_eslint_use_global = 1
```

That's all, Happy coding...
