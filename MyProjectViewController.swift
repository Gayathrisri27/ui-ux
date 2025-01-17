//
//  MyProjectViewController.swift
//  Zedit-UIKit
//
//  Created by Avinash on 09/11/24.
//

import UIKit

class MyProjectViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate {


    @IBOutlet weak var projectsCollectionView: UICollectionView!
    
    
    var projects: [String] = []
      var filteredProjects: [String] = []

      override func viewDidLoad() {
          super.viewDidLoad()
          
          self.setupSearchController()
          navigationController?.setNavigationBarHidden(false, animated: true)
          navigationItem.title = "My Projects"

          // Remove the top-right "+" button
          navigationItem.rightBarButtonItem = nil

          // Customize Edit button color
          let editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(toggleEditMode))
          editButton.tintColor = UIColor.systemRed
          navigationItem.leftBarButtonItem = editButton
          
          // Set up the collection view
          projectsCollectionView.dataSource = self
          projectsCollectionView.delegate = self
          projectsCollectionView.collectionViewLayout = generateLayout()
          projectsCollectionView.backgroundColor = UIColor.systemBackground
          view.backgroundColor = UIColor.systemBackground
          
          loadProjects()
          filteredProjects = projects

          // Add floating action button
          setupFloatingActionButton()
      }
      
      private func loadProjects() {
          projects = ["Project 1", "Project 2", "Project 3"]
      }
      
      // MARK: - Floating Action Button
      private func setupFloatingActionButton() {
          let fabButton = UIButton(type: .custom)
          fabButton.translatesAutoresizingMaskIntoConstraints = false
          fabButton.backgroundColor = UIColor.systemBlue
          fabButton.setImage(UIImage(systemName: "plus"), for: .normal)
          fabButton.tintColor = .white
          fabButton.layer.cornerRadius = 30
          fabButton.layer.shadowColor = UIColor.black.cgColor
          fabButton.layer.shadowOffset = CGSize(width: 2, height: 2)
          fabButton.layer.shadowOpacity = 0.3
          fabButton.layer.shadowRadius = 4
          fabButton.addTarget(self, action: #selector(didTapFloatingActionButton), for: .touchUpInside)
          fabButton.accessibilityLabel = "Add a new project"

          // Add ripple effect on tap
          fabButton.addTarget(self, action: #selector(animateFAB), for: .touchDown)

          view.addSubview(fabButton)

          NSLayoutConstraint.activate([
              fabButton.widthAnchor.constraint(equalToConstant: 60),
              fabButton.heightAnchor.constraint(equalToConstant: 60),
              fabButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
              fabButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
          ])
      }

      @objc private func didTapFloatingActionButton() {
          performSegue(withIdentifier: "Create", sender: nil)
      }

      @objc private func animateFAB(_ sender: UIButton) {
          UIView.animate(withDuration: 0.1, animations: {
              sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
          }) { _ in
              UIView.animate(withDuration: 0.1) {
                  sender.transform = .identity
              }
          }
      }
      
      @objc private func toggleEditMode() {
          projectsCollectionView.isEditing.toggle()
          navigationItem.leftBarButtonItem?.title = projectsCollectionView.isEditing ? "Done" : "Edit"
      }

      private func setupSearchController() {
          let searchController = UISearchController(searchResultsController: nil)
          searchController.searchResultsUpdater = self
          searchController.obscuresBackgroundDuringPresentation = false
          searchController.searchBar.placeholder = "Search Projects"
          navigationItem.searchController = searchController
          navigationItem.hidesSearchBarWhenScrolling = false
      }

      private func generateLayout() -> UICollectionViewLayout {
          let layout = UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
              let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
              let item = NSCollectionLayoutItem(layoutSize: itemSize)
              item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

              let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(100))
              let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

              let section = NSCollectionLayoutSection(group: group)
              section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
              return section
          }
          return layout
      }

      func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
          return filteredProjects.count
      }

      func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
          let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProjectCell", for: indexPath)
          cell.layer.cornerRadius = 12
          cell.layer.shadowColor = UIColor.black.cgColor
          cell.layer.shadowOffset = CGSize(width: 0, height: 2)
          cell.layer.shadowOpacity = 0.2
          cell.layer.shadowRadius = 4
          cell.backgroundColor = UIColor.systemGray5
          
          if let label = cell.contentView.viewWithTag(1) as? UILabel {
              label.text = filteredProjects[indexPath.row]
          }
          return cell
      }
  }

  // MARK: - UISearchResultsUpdating
  extension MyProjectViewController: UISearchResultsUpdating {
      func updateSearchResults(for searchController: UISearchController) {
          let searchText = searchController.searchBar.text ?? ""
          filteredProjects = searchText.isEmpty ? projects : projects.filter { $0.localizedCaseInsensitiveContains(searchText) }
          projectsCollectionView.reloadData()
      }
  }
