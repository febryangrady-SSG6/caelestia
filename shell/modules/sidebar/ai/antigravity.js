.pragma library

// The Antigravity CLI (`agy`) as the AI assistant uses it: building its command
// line and turning its stream-json output into typed updates for a reply. No
// QML types here, so this can be tested on its own; ClaudeCodeSession.qml runs
// the process.

// --- Command line ------------------------------------------------------------

var bypassMode = "bypassPermissions";

// Parses `agy models` output into ["default", ...modelIds], preserving the
// CLI's tier ordering while stripping spinner/warning lines and ANSI codes.
function parseModelList(text) {
    var clean = String(text || "").replace(/\x1b\[[0-9;]*[a-zA-Z]/g, "");
    var ids = [];
    var seen = {};
    var lines = clean.split(/[\r\n]+/);
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "" || line.indexOf("Fetching ") !== -1 || line.indexOf("warning:") === 0)
            continue;
        var m = line.match(/^([a-zA-Z0-9][a-zA-Z0-9._:-]*)(?:\s+.*)?$/);
        if (!m)
            continue;
        var id = m[1];
        if (id.indexOf("-") === -1 || seen[id])
            continue;
        seen[id] = true;
        ids.push(id);
    }
    return ["default"].concat(ids);
}

// `agy` encodes effort into most model ids (-low/-medium/-high/-xhigh); only
// offer the --effort flag when using "default" or an un-suffixed model id.
function effortLevelsFor(model) {
    var m = String(model || "default").toLowerCase();
    if (m === "default" || !/-(low|medium|high|xhigh|max)$/.test(m))
        return ["low", "medium", "high", "xhigh", "max"];
    return [];
}

function effectivePermissionMode(mode, bypassAllowed) {
    mode = mode || (bypassAllowed ? bypassMode : "default");
    if (mode === bypassMode && !bypassAllowed)
        return "default";
    if (mode === "auto")
        return "default";
    return mode;
}

function permissionArgs(mode, bypassAllowed) {
    mode = effectivePermissionMode(mode, bypassAllowed);
    if (mode === bypassMode)
        return ["--dangerously-skip-permissions"];
    if (mode === "acceptEdits")
        return ["--mode", "accept-edits"];
    if (mode === "plan")
        return ["--mode", "plan"];
    return [];
}

// The command for one reply. opts: { bin, prompt, attachments, permissionMode,
// bypassAllowed, model, effort, sessionId }.
function replyCommand(opts) {
    var cmd = [opts.bin, "-p", opts.prompt];

    // Attachments can live outside the working directory (e.g. pasted
    // screenshots in cache); allow the CLI to read them via repeatable --add-dir.
    var dirs = [];
    var attachments = opts.attachments || [];
    for (var a = 0; a < attachments.length; a++) {
        var d = attachments[a].replace(/\/[^\/]*$/, "") || "/";
        if (dirs.indexOf(d) === -1)
            dirs.push(d);
    }
    for (var j = 0; j < dirs.length; j++)
        cmd.push("--add-dir", dirs[j]);

    cmd.push("--output-format", "stream-json");
    cmd = cmd.concat(permissionArgs(opts.permissionMode, opts.bypassAllowed));

    var model = opts.model || "default";
    if (model !== "default")
        cmd.push("--model", model);

    var effort = opts.effort || "default";
    if (effort !== "default" && effortLevelsFor(model).indexOf(effort) !== -1)
        cmd.push("--effort", effort);

    if (opts.sessionId)
        cmd.push("--conversation", opts.sessionId);

    return cmd;
}

function withAttachmentList(text, paths) {
    if (!paths || paths.length === 0)
        return text;
    return ((text || "").trim() + "\n\nAttached files (use view_file to read them):\n"
        + paths.map(p => "- " + p).join("\n")).trim();
}

// The conversation so far as one prompt, to seed a fresh CLI session when no
// conversation id is available or after changing working directory.
function transcript(messages) {
    var lines = [];
    for (var i = 0; i < messages.length; i++) {
        var m = messages[i];
        if (!m.isUser && !m.isFinished)
            continue;
        var t = (m.text || "").trim();
        if (m.isUser && (m.attachments || "") !== "")
            t = withAttachmentList(t, m.attachments.split("\n"));
        if (t === "")
            continue;
        lines.push((m.isUser ? "User: " : "Assistant: ") + t);
    }
    if (lines.length <= 1)
        return "";
    return "Continue this conversation. Conversation so far:\n\n" + lines.join("\n\n") + "\n\nReply to the last user message.";
}

// --- Formatting --------------------------------------------------------------

function isAgentTool(name) {
    return name === "invoke_subagent" || name === "browser_subagent" || name === "Agent" || name === "Task";
}

function toolSummary(name, input) {
    if (!input)
        return "";
    var s = input.CommandLine || input.TargetFile || input.AbsolutePath || input.DirectoryPath
        || input.SearchDirectory || input.Query || input.Pattern || input.Url || input.Role
        || input.Task || input.Description || input.Prompt
        || input.command || input.file_path || input.url || input.query || input.description || input.prompt || "";
    if (s === "") {
        try {
            s = JSON.stringify(input);
        } catch (e) {}
    }
    s = String(s).replace(/\s+/g, " ").trim();
    return s.length > 200 ? s.substring(0, 200) + "…" : s;
}

function shortPaths(text, home) {
    if (!text || !home)
        return text || "";
    return String(text).split(home + "/").join("~/");
}

function formatResultOutput(raw) {
    var t = String(raw || "").trim();
    return t.length > 2000 ? t.substring(0, 2000) + "\n…" : t;
}

function formatTokens(n) {
    n = n || 0;
    if (n >= 1000000)
        return (n / 1000000).toFixed(1) + "M";
    if (n >= 1000)
        return (n / 1000).toFixed(1) + "k";
    return String(n);
}

function usageSummary(r) {
    if (!r)
        return "";
    var parts = [];
    if (typeof r.duration_seconds === "number" && r.duration_seconds > 0)
        parts.push(r.duration_seconds.toFixed(1) + "s");
    if (r.num_turns)
        parts.push(r.num_turns + (r.num_turns === 1 ? " turn" : " turns"));
    var u = r.usage;
    if (u) {
        var inTok = (u.input_tokens || 0) + (u.cache_read_tokens || 0);
        parts.push(formatTokens(inTok) + " in / " + formatTokens(u.output_tokens || 0) + " out");
    }
    return parts.join(" · ");
}

function isAuthError(text) {
    if (!text)
        return false;
    var t = String(text).toLowerCase();
    var needles = ["login", "log in", "logged in", "not authenticated", "unauthenticated", "unauthorized",
        "authentication", "oauth", "invalid api key", "expired", "sign in", "credentials"];
    return needles.some(n => t.indexOf(n) !== -1);
}

var authHint = "It appears that Antigravity is not logged into your account.\n\nOpen a terminal, run `agy login`, and sign in, then try again here.";

// --- Stream ------------------------------------------------------------------

function createState() {
    return {
        sessionId: "",
        acc: "",
        thoughtAcc: "",
        tools: [],
        needSep: false,
        usage: "",
        errAcc: "",
        done: false,
        completedOutTokens: 0,
        activeStepOutChars: 0
    };
}

function findTool(st, id) {
    for (var i = 0; i < st.tools.length; i++)
        if (st.tools[i].id === id)
            return st.tools[i];
    return null;
}

function appendText(st, chunk, out) {
    if (!chunk)
        return;
    if (st.needSep) {
        if (st.acc !== "" && !/\n\n$/.test(st.acc) && !/^\n/.test(chunk))
            st.acc += "\n\n";
        st.needSep = false;
    }
    st.acc += chunk;
    st.activeStepOutChars += chunk.length;
    out.push({ type: "text", text: st.acc });
    out.push({ type: "tokens", count: st.completedOutTokens + Math.max(1, Math.round(st.activeStepOutChars / 4)) });
}

function appendThought(st, chunk, out) {
    if (!chunk)
        return;
    st.thoughtAcc += chunk;
    out.push({ type: "thought", text: st.thoughtAcc });
}

function handleStepUpdate(st, su, out) {
    if (su.conversation_id && !st.sessionId)
        st.sessionId = su.conversation_id;

    if (su.step_type === "agent_response") {
        var thoughtDelta = su.thinking_delta || su.thought_delta || su.thinking || su.thought || "";
        if (thoughtDelta !== "")
            appendThought(st, String(thoughtDelta), out);

        if (su.text_delta)
            appendText(st, String(su.text_delta), out);

        if (su.state === "DONE" && su.usage && typeof su.usage.output_tokens === "number") {
            st.completedOutTokens += su.usage.output_tokens;
            st.activeStepOutChars = 0;
            out.push({ type: "tokens", count: st.completedOutTokens });
        }
        return;
    }

    if (su.step_type === "tool") {
        var id = "step_" + String(su.step_index);
        var ti = su.tool_info || {};
        var name = su.tool_name || ti.name || "tool";
        var params = ti.parameters || {};
        var t = findTool(st, id);

        if (!t) {
            t = {
                id: id,
                name: name,
                summary: toolSummary(name, params),
                done: false,
                isError: false,
                result: ""
            };
            if (isAgentTool(name))
                t.agentType = params.Role || name;
            st.tools.push(t);
            if (st.acc.trim() !== "")
                st.needSep = true;
            out.push({ type: "toolStarted", name: name });
            out.push({ type: "tools", tools: st.tools });
        } else if (t.summary === "" && params) {
            t.summary = toolSummary(name, params);
        }

        if (su.state === "DONE" || su.state === "ERROR" || ti.output !== undefined || ti.error !== undefined) {
            t.done = true;
            t.isError = (su.state === "ERROR") || Boolean(ti.is_error) || Boolean(ti.error);
            t.result = formatResultOutput(ti.error || ti.output || "");
            out.push({ type: "tools", tools: st.tools });
            out.push({ type: "toolsDone" });
        }
    }
}

function handleResult(st, r, out) {
    if (r.conversation_id)
        st.sessionId = r.conversation_id;

    var status = String(r.status || "").toUpperCase();
    var errored = (status !== "" && status !== "SUCCESS") || Boolean(r.error);
    var resText = r.response !== undefined && r.response !== null ? String(r.response) : "";
    var errText = r.error ? String(r.error) : resText;

    st.usage = usageSummary(r);

    if (st.done) {
        out.push({ type: "usage", text: st.usage });
        return;
    }

    if (errored && (isAuthError(errText) || isAuthError(st.errAcc)))
        st.acc = authHint;
    else if (st.acc.trim() === "" && resText !== "")
        st.acc = resText;
    else if (errored && errText !== "" && st.acc.indexOf(errText) === -1)
        st.acc = st.acc.replace(/\s+$/, "") + "\n\n⚠️ " + errText;

    out.push({ type: "finished", reply: finish(st) });
}

function handleLine(st, line) {
    var trimmed = (line || "").trim();
    if (trimmed === "" || trimmed[0] !== "{")
        return [];
    var evt;
    try {
        evt = JSON.parse(trimmed);
    } catch (e) {
        return [];
    }

    if (evt.conversation_id && !st.sessionId)
        st.sessionId = evt.conversation_id;

    var out = [];
    if (evt.event === "step_update" && evt.step_update) {
        handleStepUpdate(st, evt.step_update, out);
    } else if (evt.event === "result" && evt.result) {
        handleResult(st, evt.result, out);
    } else if (evt.event === "error" || evt.error) {
        var msg = String(evt.error || evt.message || "");
        if (msg !== "")
            st.errAcc += msg + "\n";
    }
    return out;
}

function finish(st) {
    st.done = true;
    for (var i = 0; i < st.tools.length; i++)
        st.tools[i].done = true;
    return { text: st.acc.trim(), tools: st.tools, usage: st.usage, sessionId: st.sessionId };
}

function handleExit(st, code, stopped) {
    if (st.done)
        return null;
    if (st.acc.trim() === "" && !stopped) {
        if (isAuthError(st.errAcc)) {
            st.acc = authHint;
        } else if (code !== 0) {
            var err = st.errAcc.trim();
            var lines = err.split("\n");
            if (lines.length > 20)
                err = lines.slice(lines.length - 20).join("\n");
            st.acc = "⚠️ Antigravity exited with code " + code + "."
                + (err !== "" ? "\n\n```\n" + err + "\n```" : "\n\nIs the `agy` CLI installed and logged in? Try running `agy login` in a terminal.");
        }
    }
    return finish(st);
}
