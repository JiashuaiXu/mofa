import json
import pyarrow as pa
from mae.kernel.utils.log import write_agent_log
from mae.kernel.utils.util import load_agent_config
from mae.run.run import run_dspy_agent, run_crewai_agent
from mae.utils.files.read import read_yaml
import argparse
import os
from dora import Node

RUNNER_CI = True if os.getenv("CI") == "true" else False


def main():
    parser = argparse.ArgumentParser(description="Reasoner Agent")
    parser.add_argument(
        "--name",
        type=str,
        required=False,
        help="The name of the node in the dataflow.",
        default="reasoner",
    )
    parser.add_argument(
        "--task",
        type=str,
        required=False,
        help="Tasks required for the Reasoner agent.",
        default="Paris Olympics",
    )
    args = parser.parse_args()
    node = Node(
        args.name,
    )
    for event in node:
        if event["type"] == "INPUT" and event['id'] in ['task','data'] :
            task = event["value"][0].as_py()
            yaml_file_path = 'reasoner_agent.yml'
            inputs = load_agent_config(yaml_file_path)
            if inputs.get('check_log_prompt', None) is True:
                log_config = {}
                agent_config = read_yaml(yaml_file_path).get('AGENT', '')
                agent_config['task'] = task
                log_config[' Agent Prompt'] = agent_config
                write_agent_log(log_type=inputs.get('log_type', None), log_file_path=inputs.get('log_path', None),
                                data=log_config)

            if 'agents' not in inputs.keys():
                inputs['task'] = task
                result = run_dspy_agent(inputs=inputs)
            else:
                result = run_crewai_agent(crewai_config=inputs)
            log_result = {inputs.get('log_step_name', "Step_one"): result}
            results = {}
            write_agent_log(log_type=inputs.get('log_type', None), log_file_path=inputs.get('log_path', None),
                            data=log_result)
            results['task'] = task
            results['result'] = result
            print('agent_output:', results)
            node.send_output("reasoner_result", pa.array([json.dumps(results)]), event['metadata'])

if __name__ == "__main__":
    main()

