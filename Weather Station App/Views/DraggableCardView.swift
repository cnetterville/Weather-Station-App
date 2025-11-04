//
//  DraggableCardView.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI
import UniformTypeIdentifiers

// Simplified drop delegate for card reordering
struct CardReorderDropDelegate: DropDelegate {
    let destinationCard: CardType
    @Binding var cardOrder: [CardType]
    @Binding var draggingCard: CardType?
    
    func performDrop(info: DropInfo) -> Bool {
        print("🎯 performDrop called for: \(destinationCard.displayName)")
        draggingCard = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        print("📍 dropEntered for: \(destinationCard.displayName)")
        print("   Current dragging card: \(draggingCard?.displayName ?? "none")")
        print("   Current order count: \(cardOrder.count)")
        
        guard let draggingCard = draggingCard else { 
            print("⚠️ No dragging card set")
            return 
        }
        
        guard let sourceIndex = cardOrder.firstIndex(of: draggingCard),
              let destinationIndex = cardOrder.firstIndex(of: destinationCard) else {
            print("❌ Could not find card indices")
            print("   Looking for source: \(draggingCard.rawValue)")
            print("   Looking for dest: \(destinationCard.rawValue)")
            print("   Current order: \(cardOrder.map { $0.rawValue })")
            return
        }
        
        if sourceIndex != destinationIndex {
            print("📦 Moving \(draggingCard.displayName) from position \(sourceIndex) to \(destinationIndex)")
            
            // Try without animation first
            let movedCard = cardOrder.remove(at: sourceIndex)
            
            // Adjust destination if needed
            let adjustedDestination = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex
            cardOrder.insert(movedCard, at: adjustedDestination)
            
            print("✅ New order: \(cardOrder.map { $0.displayName })")
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        print("🔄 dropUpdated for: \(destinationCard.displayName)")
        return DropProposal(operation: .move)
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        let isValid = draggingCard != nil
        print("✓ validateDrop for \(destinationCard.displayName): \(isValid)")
        return isValid
    }
}