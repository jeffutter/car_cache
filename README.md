# CarCache

<!-- MDOC !-->

[![Elixir CI](https://github.com/jeffutter/car_cache/workflows/Elixir%20CI/badge.svg)](https://github.com/jeffutter/car_cache/actions)
[![Module Version](https://img.shields.io/hexpm/v/car_cache.svg)](https://hex.pm/packages/car_cache)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/car_cache/)
[![Total Download](https://img.shields.io/hexpm/dt/car_cache.svg)](https://hex.pm/packages/car_cache)
[![License](https://img.shields.io/hexpm/l/car_cache.svg)](https://github.com/jeffutter/car_cache/blob/main/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/jeffutter/car_cache.svg)](https://github.com/jeffutter/car_cache/commits/main)

CLOCK with adaptive replacement (CAR) cache, based on the following paper:

[CAR: Clock with Adaptive Replacement](https://www.usenix.org/legacy/publications/library/proceedings/fast04/tech/full_papers/bansal/bansal.pdf)

CAR is a self tuning cache that strives to find a balance between frequently
accessed items and recently accessed items.

CAR is fairly similar to ARC [Adaptive Replacement Cache](http://citeseer.ist.psu.edu/viewdoc/summary?doi=10.1.1.13.5210) for which there is a
good introductory explanation here: [Adaptive Replacement Cache](https://youtu.be/_XDHPhdQHMQ)

## Usage

The cache must be given a `name` and a `max_size` when started.

```elixir
{:ok, _pid} = CarCache.start_link(name: :my_cache, max_size: 1_000)
```

After the process has started you can use it based on it's name:

```elixir
> CarCache.get(:my_cache, :foo)
nil

> CarCache.insert(:my_cache, :foo, :bar)
:ok

> CarCache.get(:my_cache, :foo)
:bar
```
