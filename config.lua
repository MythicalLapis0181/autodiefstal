Config = {}

Config.NPCModel = 'ig_lestercrest_2'
Config.NPCLocation = vector4(1272.6765, -1711.8777, 54.7715, 290.6538)

Config.TheftLocations = {
    vector4(-273.0579, -761.4432, 43.1934, 69.4513),
    vector4(-935.8204, -2692.4268, 26.2027, 62.5362),
    vector4(1372.6315, -1521.0721, 56.8692, 199.9697),
    vector4(391.2295, -739.8934, 28.8824, 181.7163)
}

Config.NPCBlip = {
    Enabled = true,
    Sprite = 225,
    Color = 5,
    Scale = 0.8,
    Label = 'Autodiefstal'
}

Config.Vehicles = {
    'adder',
    't20',
    'sultan',
    'zentorno'
}

Config.DeliveryPoints = {
    vector3(190.9457, 2787.5203, 45.2087),
    vector3(-773.4052, 5582.7168, 33.0623),
    vector3(-121.0622, 6559.1313, 29.1070)
}

Config.Cooldown = 30
Config.PoliceJobs = {'police', 'kmar'}
Config.RestrictedJobs = {'police', 'kmar', 'offpolice', 'offkmar'}
Config.MinPolice = 1

Config.TrackingDuration = 5
Config.LiveLocationUpdateInterval = 10
Config.PoliceRadius = 150.0

Config.PoliceAcceptKey = 47
Config.PoliceAcceptTime = 15

Config.SkillCheckDifficulty = {'easy', 'medium', 'medium'}

Config.RequiredItem = 'lockpick'
Config.RemoveItem = true
Config.RewardAccount = 'black_money'
Config.RewardAmount = {min = 15000, max = 35000}
