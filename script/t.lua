-- t.lua (Server)
-- Simple Roblox pathfinding script + RemoteEvent handler to move the target up/down.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configure these names to match your place
local NPC_NAME = "NPC"         -- Model with a Humanoid and HumanoidRootPart
local TARGET_NAME = "Target"   -- Part or any BasePart to path to
local MOVE_STEP = 5            -- studs moved per button press
local MOVE_COOLDOWN = 0.25     -- seconds per-player cooldown to avoid spam

local npcModel = workspace:WaitForChild(NPC_NAME)
local humanoid = npcModel:WaitForChild("Humanoid")
local hrp = npcModel:WaitForChild("HumanoidRootPart")
local target = workspace:WaitForChild(TARGET_NAME)

-- Ensure a RemoteEvent exists for the buttons
local event = ReplicatedStorage:FindFirstChild("MoveTargetEvent")
if not event then
    event = Instance.new("RemoteEvent")
    event.Name = "MoveTargetEvent"
    event.Parent = ReplicatedStorage
end

-- Simple per-player cooldown to prevent spam/exploit
local lastMove = {}

event.OnServerEvent:Connect(function(player, direction)
    if not direction or (direction ~= "Up" and direction ~= "Down") then
        return
    end
    if not target or not target.Parent or not target:IsA("BasePart") then
        return
    end

    local now = tick()
    local last = lastMove[player.UserId] or 0
    if now - last < MOVE_COOLDOWN then
        return
    end
    lastMove[player.UserId] = now

    local dy = (direction == "Up") and MOVE_STEP or -MOVE_STEP
    local newPos = target.Position + Vector3.new(0, dy, 0)
    if newPos.Y < 0.5 then newPos = Vector3.new(newPos.X, 0.5, newPos.Z) end

    -- Move the target safely (set CFrame to avoid physics jitter)
    target.CFrame = CFrame.new(newPos)
end)

-- Pathfinding options (tweak as needed)
local pathParams = {
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = true,
    AgentJumpHeight = 7
}

local function computeAndFollow()
    -- Compute a path from the NPC to the target
    local path = PathfindingService:CreatePath(pathParams)
    path:Compute(hrp.Position, target.Position)

    if path.Status == Enum.PathStatus.NoPath then
        warn("Pathfinding: no path to target")
        return false
    elseif path.Status ~= Enum.PathStatus.Success then
        warn("Pathfinding: unexpected status", path.Status)
        return false
    end

    local waypoints = path:GetWaypoints()
    for _, waypoint in ipairs(waypoints) do
        if not target.Parent then
            return true -- target removed, stop
        end

        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end

        humanoid:MoveTo(waypoint.Position)
        local reached = humanoid.MoveToFinished:Wait() -- returns true/false

        if not reached then
            -- If MoveTo failed (blocked), abort so we can recompute a new path
            return false
        end
    end

    return true
end

-- Main loop: continuously try to path to the target. Recomputes on failure or if the target moves.
spawn(function()
    while target and target.Parent do
        local ok = computeAndFollow()
        if ok then
            -- Reached the end of the path; check if we're close enough to target
            local dist = (hrp.Position - target.Position).Magnitude
            if dist > 4 then
                -- Not actually at target (maybe target moved); recompute quickly
                wait(0.2)
            else
                -- Arrived; pause before re-checking (target might move later)
                wait(1)
            end
        else
            -- Failed to follow path: wait briefly, then try again
            wait(0.5)
        end
    end
end)