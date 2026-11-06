---
title: Ash
lead: C で書いた小さなカーネルから、Forth で育てていく ANS Forth 処理系の記録。
repo: https://github.com/keix/ash
color: orange
---
Ash は、C11 で書いている ANS Forth の処理系です。C で書くのは Forth が動き出すのに要る部分だけで、残りは Forth で書いています。x86_64 向けの JIT も持っています。目指しているのは、最も単純で力強く、明確な境界を持つプログラムです。
