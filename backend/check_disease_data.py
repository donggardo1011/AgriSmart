import sqlite3

conn = sqlite3.connect('users.db')
cur = conn.cursor()

# Query diseases table
cur.execute("""
SELECT key, display_name, causal_agent, symptoms_summary_en, prevention_summary_en, treatment_summary_en 
FROM diseases 
LIMIT 5
""")

diseases = cur.fetchall()

print("=" * 80)
print("DISEASES IN DATABASE")
print("=" * 80)

for disease in diseases:
    print(f"\nKey: {disease[0]}")
    print(f"Name: {disease[1]}")
    print(f"Causal Agent: {disease[2]}")
    print(f"Symptoms: {disease[3][:100] if disease[3] else 'NULL'}...")
    print(f"Prevention: {disease[4][:100] if disease[4] else 'NULL'}...")
    print(f"Treatment: {disease[5][:100] if disease[5] else 'NULL'}...")

conn.close()
