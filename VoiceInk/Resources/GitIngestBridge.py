#!/usr/bin/env python3
"""
GitIngest Bridge Script for VoiceInk
Provides a JSON interface to the gitingest Python package
"""

import json
import sys
import asyncio
import traceback
from datetime import datetime
from pathlib import Path

def main():
    try:
        # Parse configuration from command line argument
        if len(sys.argv) != 2:
            raise ValueError("Usage: GitIngestBridge.py <config_json>")
        
        config_str = sys.argv[1]
        config = json.loads(config_str)
        
        # Validate required fields
        if 'path' not in config:
            raise ValueError("Missing required field: path")
        
        # Import gitingest (check availability)
        try:
            from gitingest import ingest
        except ImportError as e:
            raise ImportError(f"GitIngest package not available: {e}")
        
        # Extract configuration parameters
        repo_path = config['path']
        token = config.get('token')
        include_submodules = config.get('includeSubmodules', False)
        include_gitignored = config.get('includeGitignored', False)
        
        # Validate path exists
        if not Path(repo_path).exists():
            raise FileNotFoundError(f"Repository path does not exist: {repo_path}")
        
        # Build kwargs with optional filters
        kwargs = dict(
            source=repo_path,
            token=token,
            include_submodules=include_submodules,
            include_gitignored=include_gitignored
        )
        include_patterns = config.get('includePatterns')
        exclude_patterns = config.get('excludePatterns')
        max_file_size = config.get('maxFileSize')
        branch = config.get('branch')
        if include_patterns:
            kwargs['include_patterns'] = include_patterns
        if exclude_patterns:
            kwargs['exclude_patterns'] = exclude_patterns
        if max_file_size:
            try:
                kwargs['max_file_size'] = int(max_file_size)
            except Exception:
                pass
        if branch:
            kwargs['branch'] = branch

        # Execute gitingest
        summary, tree, content = ingest(**kwargs)

        # Normalize summary to a dictionary to ease Swift decoding
        if hasattr(summary, '__dict__'):
            summary_dict = summary.__dict__
        elif isinstance(summary, dict):
            summary_dict = summary
        elif hasattr(summary, '_asdict'):
            summary_dict = summary._asdict()
        else:
            summary_dict = {'raw': str(summary)}
        
        # Process summary (handle different return types)
        summary_dict = {}
        if hasattr(summary, '__dict__'):
            summary_dict = summary.__dict__
        elif isinstance(summary, dict):
            summary_dict = summary
        elif hasattr(summary, '_asdict'):  # namedtuple
            summary_dict = summary._asdict()
        else:
            # Fallback: try to extract basic info from string representation
            summary_str = str(summary)
            summary_dict = {'raw': summary_str}
        
        # Prepare result
        result = {
            'summary': summary_dict,
            'tree': str(tree) if tree else '',
            'content': str(content) if content else '',
            'timestamp': datetime.utcnow().isoformat(),
            'config': {
                'path': repo_path,
                'includeSubmodules': include_submodules,
                'includeGitignored': include_gitignored,
                'tokenProvided': token is not None
            }
        }
        
        # Output result as JSON
        print(json.dumps(result, indent=None, separators=(',', ':')))
        
    except Exception as e:
        # Output error information
        error_result = {
            'error': str(e),
            'errorType': type(e).__name__,
            'traceback': traceback.format_exc(),
            'timestamp': datetime.utcnow().isoformat()
        }
        
        print(json.dumps(error_result, indent=None, separators=(',', ':')), file=sys.stderr)
        sys.exit(1)

async def async_main():
    """Async version for future use with async gitingest API"""
    try:
        # Parse configuration
        if len(sys.argv) != 2:
            raise ValueError("Usage: GitIngestBridge.py <config_json>")
        
        config_str = sys.argv[1]
        config = json.loads(config_str)
        
        # Import async version if available
        try:
            from gitingest import ingest_async
            
            # Execute async gitingest
            summary, tree, content = await ingest_async(
                source=config['path'],
                token=config.get('token'),
                include_submodules=config.get('includeSubmodules', False),
                include_gitignored=config.get('includeGitignored', False)
            )
            
        except ImportError:
            # Fallback to sync version
            from gitingest import ingest
            summary, tree, content = ingest(
                source=config['path'],
                token=config.get('token'),
                include_submodules=config.get('includeSubmodules', False),
                include_gitignored=config.get('includeGitignored', False)
            )
        
        # Process and output result (same as sync version)
        summary_dict = {}
        if hasattr(summary, '__dict__'):
            summary_dict = summary.__dict__
        elif isinstance(summary, dict):
            summary_dict = summary
        else:
            summary_dict = {'raw': str(summary)}
        
        result = {
            'summary': summary_dict,
            'tree': str(tree),
            'content': str(content),
            'timestamp': datetime.utcnow().isoformat()
        }
        
        print(json.dumps(result, indent=None, separators=(',', ':')))
        
    except Exception as e:
        error_result = {
            'error': str(e),
            'errorType': type(e).__name__,
            'traceback': traceback.format_exc(),
            'timestamp': datetime.utcnow().isoformat()
        }
        
        print(json.dumps(error_result, indent=None, separators=(',', ':')), file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    # Check if we should use async version
    use_async = '--async' in sys.argv
    if use_async:
        sys.argv.remove('--async')
        asyncio.run(async_main())
    else:
        main()