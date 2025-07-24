# Every Dockerfile line that defines a new build-stage is defined by FROM <basename> AS <stagename>
# This greps all those lines and gives a list of stagenames

def get_existing_tools(df_contents):
    tools = set()  # Use a set to avoid duplicates
    for line in df_contents:
        elements = line.split()
        if len(elements) == 2 and elements[0].upper() == "ARG":
            arg_str = elements[1].split("=")[0].strip()
            # Extract the tool name from the ARG definition
            if arg_str.endswith("REPO_COMMIT"):
                # Assuming the format is like: ARG REPO_COMMIT_TOOL_NAME
                tool_name = arg_str.removesuffix("_REPO_COMMIT").lower()
                tools.add(tool_name)
    return list(tools)  # Convert back to list for consistency

def update_revision(df_contents, tool_name, new_rev):
    search_str=tool_name.upper().replace("-", "_") + "_REPO_COMMIT"
    for i,line in enumerate(df_contents):
        elem=line.split()
        if len(elem)>=2 and elem[0].upper()=="ARG" and elem[1].startswith(search_str):
            print(f"Updated line {i}")
            df_contents[i]="ARG " + search_str + "=\"" + new_rev + "\"\n"
            return True
    return False

def read_dockerfile(path="Dockerfile"):
    with open(path, mode="r") as f:
        return f.readlines()
    return None

def write_dockerfile(df_contents, path="Dockerfile"):
    with open(path, mode="w") as f:
        f.writelines(df_contents)