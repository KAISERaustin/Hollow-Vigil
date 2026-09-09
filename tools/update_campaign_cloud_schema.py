"""Generate a new cloud-schema migration from the game's exported content catalog.

Run campaign_cloud_contract.gd, then `supabase migration new <name>`, and pass
the resulting empty migration path here. Historical migrations are immutable.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
catalog = json.loads((ROOT / 'artifacts/campaign-cloud-catalog.json').read_text())
destination = pathlib.Path(sys.argv[1]).resolve()
if destination.parent != ROOT / 'supabase/migrations' or destination.read_text().strip():
    raise SystemExit('Provide an empty file created by supabase migration new')
sources = sorted((ROOT / 'supabase/migrations').glob('*.sql'), reverse=True)
for source in sources:
    schemas = re.findall(r'\$schema\$(.*?)\$schema\$::json', source.read_text(), re.S)
    if len(schemas) == 2:
        break
else:
    raise SystemExit('No existing Campaign schema found')

def field_schema(limits):
    return dict(type='integer' if limits.get('integer') else 'number',
                minimum=limits['min'], maximum=limits['max'])

for index, raw in enumerate(schemas):
    schema = json.loads(raw)
    definitions = schema['definitions']
    for category, kinds in catalog['stats'].items():
        category_properties = {}
        for kind, fields in kinds.items():
            name = category + '_' + kind.replace(':', '_')
            if category in catalog['attribute_fields']:
                attributes = catalog['attribute_fields'][category]
                properties = {key: field_schema(value) for key, value in attributes.items()}
                for key, limits in fields.items():
                    properties[key] = field_schema(limits)
            else:
                properties = {key: field_schema(value) for key, value in fields.items()}
            definitions[name] = dict(type='object', properties=properties, additionalProperties=False)
            category_properties[kind] = {'$ref': '#/definitions/' + name}
        definitions['stats']['properties'][category] = dict(type='object', properties=category_properties, additionalProperties=False)
    schemas[index] = json.dumps(schema, separators=(',', ':'))

destination.write_text("-- Generated from the shared content node catalog.\n"
    "create or replace function public.campaign_document_schema(document_kind text) returns json\n"
    "language sql immutable set search_path='' as $fn$\n"
    "select case document_kind when 'build' then $schema$" + schemas[0] + "$schema$::json\n"
    "when 'snapshot' then $schema$" + schemas[1] + "$schema$::json end;\n$fn$;\n"
    "notify pgrst,'reload schema';\n")
print(destination)
