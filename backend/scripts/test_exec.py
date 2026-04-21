from pathlib import Path
p = Path(__file__).resolve().parent.parent / 'backend_test_exec.log'
p.write_text('executed')
print('done')
