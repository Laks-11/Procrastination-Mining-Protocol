// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract ProcrastinationMiningProtocol {
    
    // Structs
    struct Task {
        address owner;
        string description;
        uint256 stakeAmount;
        uint256 deadline;
        bool completed;
        bool exists;
        uint256 createdAt;
    }
    
    struct UserStats {
        uint256 totalTasks;
        uint256 completedTasks;
        uint256 currentStreak;
        uint256 maxStreak;
        uint256 totalStaked;
        uint256 totalRewards;
    }
    
    // State variables
    mapping(uint256 => Task) public tasks;
    mapping(address => UserStats) public userStats;
    mapping(address => uint256[]) public userTasks;
    mapping(address => uint256) public pendingRewards;
    
    uint256 public nextTaskId;
    uint256 public totalProtocolStake;
    uint256 public rewardPool;
    uint256 public constant MIN_STAKE = 0.01 ether;
    uint256 public constant REWARD_MULTIPLIER = 150; // 1.5x reward for completion
    uint256 public constant STREAK_BONUS = 10; // 10% bonus per streak level
    
    // Events
    event TaskCreated(uint256 indexed taskId, address indexed user, string description, uint256 stakeAmount, uint256 deadline);
    event TaskCompleted(uint256 indexed taskId, address indexed user, uint256 reward);
    event TaskExpired(uint256 indexed taskId, address indexed user, uint256 lostStake);
    event RewardsClaimed(address indexed user, uint256 amount);
    event StreakUpdated(address indexed user, uint256 newStreak);
    
    // Modifiers
    modifier validTask(uint256 _taskId) {
        require(tasks[_taskId].exists, "Task does not exist");
        require(tasks[_taskId].owner == msg.sender, "Not task owner");
        _;
    }
    
    modifier taskNotCompleted(uint256 _taskId) {
        require(!tasks[_taskId].completed, "Task already completed");
        _;
    }
    
    // Function 1: Create a new procrastination task with stake
    function createTask(string memory _description, uint256 _durationHours) external payable {
        require(msg.value >= MIN_STAKE, "Insufficient stake amount");
        require(_durationHours > 0 && _durationHours <= 168, "Invalid duration (1-168 hours)");
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        uint256 deadline = block.timestamp + (_durationHours * 1 hours);
        
        tasks[nextTaskId] = Task({
            owner: msg.sender,
            description: _description,
            stakeAmount: msg.value,
            deadline: deadline,
            completed: false,
            exists: true,
            createdAt: block.timestamp
        });
        
        userTasks[msg.sender].push(nextTaskId);
        userStats[msg.sender].totalTasks++;
        userStats[msg.sender].totalStaked += msg.value;
        totalProtocolStake += msg.value;
        
        emit TaskCreated(nextTaskId, msg.sender, _description, msg.value, deadline);
        nextTaskId++;
    }
    
    // Function 2: Complete a task and claim rewards
    function completeTask(uint256 _taskId) external validTask(_taskId) taskNotCompleted(_taskId) {
        Task storage task = tasks[_taskId];
        require(block.timestamp <= task.deadline, "Task deadline has passed");
        
        task.completed = true;
        
        // Update user stats
        UserStats storage stats = userStats[msg.sender];
        stats.completedTasks++;
        stats.currentStreak++;
        
        if (stats.currentStreak > stats.maxStreak) {
            stats.maxStreak = stats.currentStreak;
        }
        
        // Calculate rewards with streak bonus
        uint256 baseReward = (task.stakeAmount * REWARD_MULTIPLIER) / 100;
        uint256 streakBonus = (baseReward * stats.currentStreak * STREAK_BONUS) / 100;
        uint256 totalReward = baseReward + streakBonus;
        
        // Add to pending rewards
        pendingRewards[msg.sender] += totalReward;
        stats.totalRewards += totalReward;
        
        // Remove stake from protocol
        totalProtocolStake -= task.stakeAmount;
        
        emit TaskCompleted(_taskId, msg.sender, totalReward);
        emit StreakUpdated(msg.sender, stats.currentStreak);
    }
    
    // Function 3: Process expired tasks and distribute to reward pool
    function processExpiredTask(uint256 _taskId) external {
        Task storage task = tasks[_taskId];
        require(task.exists, "Task does not exist");
        require(block.timestamp > task.deadline, "Task not yet expired");
        require(!task.completed, "Task was completed");
        
        // Reset user streak
        userStats[task.owner].currentStreak = 0;
        
        // Add stake to reward pool
        rewardPool += task.stakeAmount;
        totalProtocolStake -= task.stakeAmount;
        
        // Mark task as processed by setting completed to true
        task.completed = true;
        
        emit TaskExpired(_taskId, task.owner, task.stakeAmount);
        emit StreakUpdated(task.owner, 0);
    }
    
    // Function 4: Claim pending rewards
    function claimRewards() external {
        uint256 amount = pendingRewards[msg.sender];
        require(amount > 0, "No pending rewards");
        
        pendingRewards[msg.sender] = 0;
        
        // Add bonus from reward pool based on completion rate
        UserStats memory stats = userStats[msg.sender];
        if (stats.totalTasks > 0 && rewardPool > 0) {
            uint256 completionRate = (stats.completedTasks * 100) / stats.totalTasks;
            uint256 poolBonus = (rewardPool * completionRate) / 10000; // Max 1% of pool
            
            if (poolBonus > 0) {
                amount += poolBonus;
                rewardPool -= poolBonus;
            }
        }
        
        payable(msg.sender).transfer(amount);
        emit RewardsClaimed(msg.sender, amount);
    }
    
    // Function 5: Get user's active tasks
    function getUserActiveTasks(address _user) external view returns (uint256[] memory activeTasks) {
        uint256[] memory allTasks = userTasks[_user];
        uint256 activeCount = 0;
        
        // Count active tasks
        for (uint256 i = 0; i < allTasks.length; i++) {
            if (!tasks[allTasks[i]].completed && block.timestamp <= tasks[allTasks[i]].deadline) {
                activeCount++;
            }
        }
        
        // Create array of active task IDs
        activeTasks = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allTasks.length; i++) {
            if (!tasks[allTasks[i]].completed && block.timestamp <= tasks[allTasks[i]].deadline) {
                activeTasks[index] = allTasks[i];
                index++;
            }
        }
        
        return activeTasks;
    }
    
    // View functions
    function getTaskDetails(uint256 _taskId) external view returns (
        address owner,
        string memory description,
        uint256 stakeAmount,
        uint256 deadline,
        bool completed,
        uint256 createdAt,
        bool isExpired
    ) {
        Task memory task = tasks[_taskId];
        return (
            task.owner,
            task.description,
            task.stakeAmount,
            task.deadline,
            task.completed,
            task.createdAt,
            block.timestamp > task.deadline
        );
    }
    
    function getUserStats(address _user) external view returns (UserStats memory) {
        return userStats[_user];
    }
    
    function getProtocolStats() external view returns (
        uint256 totalTasks,
        uint256 totalStake,
        uint256 currentRewardPool
    ) {
        return (nextTaskId, totalProtocolStake, rewardPool);
    }
    
    // Function 6: Extend task deadline (with penalty)
    function extendTaskDeadline(uint256 _taskId, uint256 _additionalHours) external payable validTask(_taskId) taskNotCompleted(_taskId) {
        Task storage task = tasks[_taskId];
        require(block.timestamp <= task.deadline, "Cannot extend expired task");
        require(_additionalHours > 0 && _additionalHours <= 24, "Extension must be 1-24 hours");
        
        // Calculate extension penalty (50% of original stake)
        uint256 extensionPenalty = task.stakeAmount / 2;
        require(msg.value >= extensionPenalty, "Insufficient penalty payment");
        
        // Extend deadline
        task.deadline += (_additionalHours * 1 hours);
        
        // Add penalty to reward pool
        rewardPool += msg.value;
        
        // Reset current streak as penalty for extending
        userStats[msg.sender].currentStreak = 0;
        
        emit TaskCreated(_taskId, msg.sender, task.description, task.stakeAmount, task.deadline); // Reuse event for extension
        emit StreakUpdated(msg.sender, 0);
    }
    
    // Emergency functions
    function emergencyWithdraw() external {
        require(msg.sender == address(this), "Only contract can call");
        payable(msg.sender).transfer(address(this).balance);
    }
}  
//"added one function suggested by chatgpt"
