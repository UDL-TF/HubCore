import re
import time

# 定义全局存储赏金信息的字典
bounties = {}

# 函数: 设置赏金
def sm_bounty(player_name, target_player, credits, kill_count):
    """
    设置玩家对目标玩家的赏金
    
    :param player_name: 发起赏金的玩家名字
    :param target_player: 被设置赏金的目标玩家
    :param credits: 赏金金额
    :param kill_count: 需要击杀目标的次数
    """
    if target_player == player_name:
        return "不能为自己设置赏金！"

    if credits <= 0 or kill_count <= 0:
        return "赏金金额和击杀次数必须大于零！"

    # 更新赏金信息
    bounties[target_player] = {
        'credits': credits,
        'kill_count': kill_count,
        'issuer': player_name,
        'timestamp': time.time()
    }

    return f"已为 {target_player} 设置赏金！金额: {credits}，需要击杀次数: {kill_count}"

# 函数: 获取赏金信息
def get_bounty_info(target_player):
    """
    获取目标玩家的赏金信息
    
    :param target_player: 被查询赏金的玩家名字
    :return: 赏金信息
    """
    if target_player not in bounties:
        return f"{target_player} 没有被设置赏金。"
    
    bounty = bounties[target_player]
    credits = bounty['credits']
    kill_count = bounty['kill_count']
    issuer = bounty['issuer']
    return f"{target_player} 的赏金由 {issuer} 设置，赏金金额: {credits}，需要击杀次数: {kill_count}."

# 测试用例
def test_sm_bounty():
    assert sm_bounty("player1", "player2", 100, 3) == "已为 player2 设置赏金！金额: 100，需要击杀次数: 3"
    assert sm_bounty("player1", "player1", 100, 3) == "不能为自己设置赏金！"
    assert sm_bounty("player1", "player2", -100, 3) == "赏金金额和击杀次数必须大于零！"
    assert sm_bounty("player1", "player2", 100, -3) == "赏金金额和击杀次数必须大于零！"
    assert get_bounty_info("player2") == "player2 的赏金由 player1 设置，赏金金额: 100，需要击杀次数: 3."

# 运行测试
test_sm_bounty()