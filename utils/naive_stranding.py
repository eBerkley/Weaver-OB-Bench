import yaml

def components_to_group(components,name):
    return {'name': name, 'components': components}


with open("trace.txt") as f:
    trace = [int(x) for x in  f.read().splitlines()]

with open("release/base/colocation/monolith.yaml") as f:
    data = yaml.safe_load(f)


components = data["groups"][0]["components"]


groups = [(t,[c]) for c,t in zip(components, trace)]
groups.sort(key=lambda x: x[0])
iters = [groups]

while len(iters[-1]) > 1:

    cur = iters[-1]

    least = cur[0]
    second = cur[1]

    colocated = (least[0] + second[0], least[1] + second[1])
    next_iter = [colocated] + cur[2:]
    next_iter.sort(key=lambda x: x[0])

    iters.append(next_iter)

for i, x in enumerate(iters):

    groups = [components_to_group(cg[1], f"group-{i+1}") for i, cg in enumerate(filter(lambda x: len(x[1]) > 1, x))]
    out = {'groups': groups}

    out = yaml.dump(out,sort_keys=False) if len(groups) > 0 else ""

    with open(f"naive_stranding_{i+1}.yaml", "w") as f:
        f.write(out)




