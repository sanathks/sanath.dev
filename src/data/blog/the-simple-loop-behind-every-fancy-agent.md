---
author: Sanath Samarasinghe
pubDatetime: 2026-03-09T00:00:00Z
modDatetime:
title: The Simple Loop Behind Every Fancy Agent
featured: false
draft: false
tags:
  - ai
  - development
  - tools
description: "Every sophisticated agent harness still boils down to this tiny loop: call the model, run tools, feed results, repeat."
---

Okay so every fancy agent framework still runs the same tiny loop. The model decides what to do, you execute a tool if it asks, you feed the result back, and you repeat until it responds normally.

```ts
import OpenAI from "openai";

const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// Tool definition the model can call
const tools = [
  {
    name: "getTime",
    description: "Returns the current time in ISO format",
    parameters: { type: "object", properties: {}, required: [] },
  },
];

// Actual tool implementation
function getTime() {
  return { now: new Date().toISOString() };
}

async function runTool(name: string, args: Record<string, any>) {
  if (name === "getTime") return getTime();
  throw new Error(`Unknown tool: ${name}`);
}

export async function agentLoop(userMessage: string) {
  const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [
    { role: "system", content: "You are a helpful assistant." },
    { role: "user", content: userMessage },
  ];

  while (true) {
    const res = await client.chat.completions.create({
      model: "gpt-4o-mini",
      messages,
      tools,
      tool_choice: "auto",
    });

    const msg = res.choices[0].message;

    if (msg.tool_calls?.length) {
      messages.push(msg);

      for (const call of msg.tool_calls) {
        const result = await runTool(
          call.function.name,
          JSON.parse(call.function.arguments || "{}")
        );

        messages.push({
          role: "tool",
          tool_call_id: call.id,
          content: JSON.stringify(result),
        });
      }

      continue;
    }

    return msg.content;
  }
}

(async () => {
  const answer = await agentLoop("What time is it right now?");
  console.log(answer);
})();
```

**What is happening**

**1. The model decides the next step.**
Each iteration either returns a normal reply or a tool call.

**2. If it asks for a tool, you run it.**
You execute the tool and capture the output.

**3. You push the tool output back in.**
That gives the model the data it needs to finish.

**4. You loop until it replies normally.**
That final reply is your answer.

That is the core of agents. You can add more tools, a step limit, or memory later, but this loop is the foundation.

ciao
