"""Compatibility entry point for the community-anchored journey generator.

The former replay-score selector is retired. It confused execution cost with
human discovery and removed repeated practice through skill-pattern deduplication.
"""
from human_journey import main

if __name__ == '__main__':
    main()
