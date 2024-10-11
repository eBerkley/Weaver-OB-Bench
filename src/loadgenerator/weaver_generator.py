for i in range(1, 7):
    for j in range(1, 7 - i):
        k = 7 - i - j
        cpus = 1  # Initialize the cpus counter
        print("replicas = [")
        # For group "i"
        for _ in range(i):
            print(f'{{group = "i" cpus = "{cpus}"}},')
            cpus += 1
        # For group "j"
        for _ in range(j):
            print(f'{{group = "j" cpus = "{cpus}"}},')
            cpus += 1
        # For group "k"
        for _ in range(k):
            print(f'{{group = "k" cpus = "{cpus}"}},')
            cpus += 1
        print("]\n")  # Close the list and add a newline for readability

