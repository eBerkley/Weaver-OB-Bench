
import yaml

def components_to_group(components,name):
    return {'name': name, 'components': components}



with open("release/base/colocation/monolith.yaml") as f:
    data = yaml.safe_load(f)


components = data["groups"][0]["components"]


groups = [[c] for c in components]
groups.sort(key=lambda x: x[0])
paired = []

for i in range(len(groups)):
    for j in range(i+1, len(groups)):
        paired.append(((i,j),[groups[i][0], groups[j][0]]))


for ((i,j),x) in paired:

    groups = [components_to_group(x, f"{i}-{j}-paired")]
    out = {'groups': groups}

    out = yaml.dump(out,sort_keys=False) if len(groups) > 0 else ""

    with open(f"paired_{i}_{j}.yaml", "w") as f:
        f.write(out)




