/// Quality tier of the AI chat experience. Drives retrieval depth + UI.
enum ChatTier { free, pro }

/// The concrete generation engine behind chat for the active tier.
enum ChatEngine { onDevice, byokCloud, premiumCloud }
